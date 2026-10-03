package pairing

import (
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"database/sql"
	"encoding/base64"
	"errors"
	"fmt"
	"net/url"
	"strings"
	"sync"
	"time"

	_ "modernc.org/sqlite"
)

var (
	ErrAlreadyPaired       = errors.New("instance is already paired")
	ErrInvitePending       = errors.New("an invitation is already pending")
	ErrInvalidInvite       = errors.New("invite is invalid")
	ErrExpiredInvite       = errors.New("invite has expired")
	ErrInvalidInviterToken = errors.New("inviter token is invalid")
	ErrInvalidSessionToken = errors.New("session token is invalid")
	ErrInvalidRecoveryCode = errors.New("recovery code is invalid")
	ErrNotPaired           = errors.New("instance is not paired")
	ErrInvalidServerURL    = errors.New("server URL is invalid")
)

const inviteTTL = 10 * time.Minute

// Invite is the one-time invitation returned to the inviting client.
type Invite struct {
	URL          string
	InviterToken string
	RecoveryCode string
	ExpiresAt    time.Time
}

// PairingStatus describes the state visible to a paired client.
type PairingStatus struct {
	PairID       string
	Status       string
	InviteeToken string
	RecoveryCode string
}

// RecoveredCredentials contains rotated credentials for a reinstalled client.
type RecoveredCredentials struct {
	PairID       string
	Role         string
	AccessToken  string
	RecoveryCode string
}

// Session is the authenticated member and pairing state for a client device.
type Session struct {
	PairID string
	Role   string
	Status string
}

// Service stores the single couple relationship for one private instance.
type Service struct {
	db  *sql.DB
	mu  sync.Mutex
	now func() time.Time
}

// OpenService opens or creates the SQLite database used by the pairing flow.
func OpenService(databasePath string) (*Service, error) {
	db, err := sql.Open("sqlite", databasePath)
	if err != nil {
		return nil, fmt.Errorf("open pairing database: %w", err)
	}
	db.SetMaxOpenConns(1)
	db.SetMaxIdleConns(1)
	if _, err := db.Exec(`PRAGMA busy_timeout = 5000`); err != nil {
		db.Close()
		return nil, fmt.Errorf("configure pairing database: %w", err)
	}
	if _, err := db.Exec(`PRAGMA foreign_keys = ON`); err != nil {
		db.Close()
		return nil, fmt.Errorf("configure pairing database: %w", err)
	}
	if _, err := db.Exec(`
		CREATE TABLE IF NOT EXISTS pairing_state (
			id INTEGER PRIMARY KEY CHECK (id = 1),
			server_url TEXT NOT NULL,
			invite_code_hash BLOB NOT NULL,
			invite_expires_at INTEGER NOT NULL,
			inviter_token_hash BLOB NOT NULL,
			inviter_recovery_hash BLOB NOT NULL,
			pair_id TEXT,
			invitee_token_hash BLOB,
			invitee_recovery_hash BLOB,
			paired INTEGER NOT NULL DEFAULT 0
		)`); err != nil {
		db.Close()
		return nil, fmt.Errorf("create pairing schema: %w", err)
	}
	return &Service{db: db, now: time.Now}, nil
}

// NewService creates an in-memory pairing service for isolated tests.
func NewService() *Service {
	service, err := OpenService(":memory:")
	if err != nil {
		panic(err)
	}
	return service
}

// Close releases the SQLite database connection.
func (service *Service) Close() error {
	return service.db.Close()
}

// CreateInvite creates one expiring invitation for the instance.
func (service *Service) CreateInvite(serverURL string) (Invite, error) {
	baseURL, err := normalizeServerURL(serverURL)
	if err != nil {
		return Invite{}, err
	}

	code, err := randomToken(32)
	if err != nil {
		return Invite{}, err
	}
	inviterToken, err := randomToken(32)
	if err != nil {
		return Invite{}, err
	}
	inviterRecovery, err := randomToken(24)
	if err != nil {
		return Invite{}, err
	}
	expiresAt := service.now().Add(inviteTTL)
	codeHash := tokenHash(code)
	inviterTokenHash := tokenHash(inviterToken)
	inviterRecoveryHash := tokenHash(inviterRecovery)

	service.mu.Lock()
	defer service.mu.Unlock()

	var paired bool
	var existingExpiry int64
	err = service.db.QueryRow(`SELECT paired, invite_expires_at FROM pairing_state WHERE id = 1`).Scan(&paired, &existingExpiry)
	switch {
	case err == nil && paired:
		return Invite{}, ErrAlreadyPaired
	case err == nil && service.now().Unix() < existingExpiry:
		return Invite{}, ErrInvitePending
	case err != nil && !errors.Is(err, sql.ErrNoRows):
		return Invite{}, fmt.Errorf("read pairing state: %w", err)
	}

	_, err = service.db.Exec(`
		INSERT INTO pairing_state (
			id, server_url, invite_code_hash, invite_expires_at,
			inviter_token_hash, inviter_recovery_hash, pair_id,
			invitee_token_hash, invitee_recovery_hash, paired
		) VALUES (1, ?, ?, ?, ?, ?, NULL, NULL, NULL, 0)
		ON CONFLICT(id) DO UPDATE SET
			server_url = excluded.server_url,
			invite_code_hash = excluded.invite_code_hash,
			invite_expires_at = excluded.invite_expires_at,
			inviter_token_hash = excluded.inviter_token_hash,
			inviter_recovery_hash = excluded.inviter_recovery_hash,
			pair_id = NULL,
			invitee_token_hash = NULL,
			invitee_recovery_hash = NULL,
			paired = 0`,
		baseURL, codeHash[:], expiresAt.Unix(), inviterTokenHash[:], inviterRecoveryHash[:])
	if err != nil {
		return Invite{}, fmt.Errorf("save pairing invitation: %w", err)
	}

	return Invite{
		URL:          "pawmate://pair?server=" + url.QueryEscape(baseURL) + "&code=" + url.QueryEscape(code),
		InviterToken: inviterToken,
		RecoveryCode: inviterRecovery,
		ExpiresAt:    expiresAt,
	}, nil
}

// RedeemInvite atomically consumes an invite and creates the instance pair.
func (service *Service) RedeemInvite(code string) (PairingStatus, error) {
	service.mu.Lock()
	defer service.mu.Unlock()

	var paired bool
	var expiresAt int64
	var storedCodeHash []byte
	err := service.db.QueryRow(`SELECT paired, invite_expires_at, invite_code_hash FROM pairing_state WHERE id = 1`).Scan(&paired, &expiresAt, &storedCodeHash)
	if errors.Is(err, sql.ErrNoRows) || paired {
		return PairingStatus{}, ErrInvalidInvite
	}
	if err != nil {
		return PairingStatus{}, fmt.Errorf("read pairing invitation: %w", err)
	}
	if service.now().Unix() >= expiresAt {
		return PairingStatus{}, ErrExpiredInvite
	}
	if !sameHash(storedCodeHash, tokenHash(strings.TrimSpace(code))) {
		return PairingStatus{}, ErrInvalidInvite
	}

	pairID, err := randomToken(16)
	if err != nil {
		return PairingStatus{}, err
	}
	inviteeToken, err := randomToken(32)
	if err != nil {
		return PairingStatus{}, err
	}
	inviteeRecovery, err := randomToken(24)
	if err != nil {
		return PairingStatus{}, err
	}
	inviteeTokenHash := tokenHash(inviteeToken)
	inviteeRecoveryHash := tokenHash(inviteeRecovery)
	result, err := service.db.Exec(`
		UPDATE pairing_state
		SET pair_id = ?, invitee_token_hash = ?, invitee_recovery_hash = ?, paired = 1
		WHERE id = 1 AND paired = 0 AND invite_code_hash = ? AND invite_expires_at > ?`,
		pairID, inviteeTokenHash[:], inviteeRecoveryHash[:], storedCodeHash, service.now().Unix())
	if err != nil {
		return PairingStatus{}, fmt.Errorf("complete pairing: %w", err)
	}
	changed, err := result.RowsAffected()
	if err != nil {
		return PairingStatus{}, fmt.Errorf("check pairing update: %w", err)
	}
	if changed != 1 {
		return PairingStatus{}, ErrInvalidInvite
	}

	return PairingStatus{
		PairID:       pairID,
		Status:       "paired",
		InviteeToken: inviteeToken,
		RecoveryCode: inviteeRecovery,
	}, nil
}

// Status returns pairing state after validating the inviter's bearer token.
func (service *Service) Status(inviterToken string) (PairingStatus, error) {
	service.mu.Lock()
	defer service.mu.Unlock()

	var paired bool
	var pairID sql.NullString
	var storedTokenHash []byte
	err := service.db.QueryRow(`SELECT paired, pair_id, inviter_token_hash FROM pairing_state WHERE id = 1`).Scan(&paired, &pairID, &storedTokenHash)
	if errors.Is(err, sql.ErrNoRows) {
		return PairingStatus{}, ErrInvalidInviterToken
	}
	if err != nil {
		return PairingStatus{}, fmt.Errorf("read pairing status: %w", err)
	}
	if !sameHash(storedTokenHash, tokenHash(strings.TrimSpace(inviterToken))) {
		return PairingStatus{}, ErrInvalidInviterToken
	}
	if !paired {
		return PairingStatus{Status: "pending"}, nil
	}
	return PairingStatus{PairID: pairID.String, Status: "paired"}, nil
}

// Authenticate validates either member's access token and returns its session.
func (service *Service) Authenticate(accessToken string) (Session, error) {
	service.mu.Lock()
	defer service.mu.Unlock()

	var paired bool
	var pairID sql.NullString
	var inviterHash, inviteeHash []byte
	err := service.db.QueryRow(`
		SELECT paired, pair_id, inviter_token_hash, invitee_token_hash
		FROM pairing_state WHERE id = 1`).Scan(&paired, &pairID, &inviterHash, &inviteeHash)
	if errors.Is(err, sql.ErrNoRows) {
		return Session{}, ErrInvalidSessionToken
	}
	if err != nil {
		return Session{}, fmt.Errorf("read pairing session: %w", err)
	}

	providedHash := tokenHash(strings.TrimSpace(accessToken))
	if sameHash(inviterHash, providedHash) {
		status := "pending"
		if paired {
			status = "paired"
		}
		return Session{PairID: pairID.String, Role: "inviter", Status: status}, nil
	}
	if paired && sameHash(inviteeHash, providedHash) {
		return Session{PairID: pairID.String, Role: "invitee", Status: "paired"}, nil
	}
	return Session{}, ErrInvalidSessionToken
}

// Recover rotates one member's credentials using their single-use recovery code.
func (service *Service) Recover(recoveryCode string) (RecoveredCredentials, error) {
	service.mu.Lock()
	defer service.mu.Unlock()

	var pairID sql.NullString
	var paired bool
	var inviterHash, inviteeHash []byte
	err := service.db.QueryRow(`
		SELECT pair_id, paired, inviter_recovery_hash, invitee_recovery_hash
		FROM pairing_state WHERE id = 1`).Scan(&pairID, &paired, &inviterHash, &inviteeHash)
	if errors.Is(err, sql.ErrNoRows) {
		return RecoveredCredentials{}, ErrNotPaired
	}
	if err != nil {
		return RecoveredCredentials{}, fmt.Errorf("read recovery state: %w", err)
	}
	if !paired {
		return RecoveredCredentials{}, ErrNotPaired
	}

	providedHash := tokenHash(strings.TrimSpace(recoveryCode))
	role := ""
	if sameHash(inviterHash, providedHash) {
		role = "inviter"
	} else if sameHash(inviteeHash, providedHash) {
		role = "invitee"
	} else {
		return RecoveredCredentials{}, ErrInvalidRecoveryCode
	}

	accessToken, err := randomToken(32)
	if err != nil {
		return RecoveredCredentials{}, err
	}
	newRecoveryCode, err := randomToken(24)
	if err != nil {
		return RecoveredCredentials{}, err
	}
	tokenColumn, recoveryColumn := "inviter_token_hash", "inviter_recovery_hash"
	if role == "invitee" {
		tokenColumn, recoveryColumn = "invitee_token_hash", "invitee_recovery_hash"
	}
	query := `UPDATE pairing_state SET ` + tokenColumn + ` = ?, ` + recoveryColumn + ` = ? WHERE id = 1 AND paired = 1`
	accessTokenHash := tokenHash(accessToken)
	newRecoveryHash := tokenHash(newRecoveryCode)
	if _, err := service.db.Exec(query, accessTokenHash[:], newRecoveryHash[:]); err != nil {
		return RecoveredCredentials{}, fmt.Errorf("rotate recovered credentials: %w", err)
	}
	return RecoveredCredentials{
		PairID:       pairID.String,
		Role:         role,
		AccessToken:  accessToken,
		RecoveryCode: newRecoveryCode,
	}, nil
}

// normalizeServerURL validates and canonicalizes the URL embedded in an invite.
func normalizeServerURL(raw string) (string, error) {
	parsed, err := url.Parse(strings.TrimSpace(raw))
	if err != nil || parsed.Host == "" || (parsed.Scheme != "http" && parsed.Scheme != "https") {
		return "", ErrInvalidServerURL
	}
	if parsed.User != nil || parsed.RawQuery != "" || parsed.Fragment != "" {
		return "", ErrInvalidServerURL
	}
	parsed.Path = strings.TrimRight(parsed.Path, "/")
	return strings.TrimRight(parsed.String(), "/"), nil
}

func tokenHash(token string) [sha256.Size]byte {
	return sha256.Sum256([]byte(token))
}

func sameHash(stored []byte, provided [sha256.Size]byte) bool {
	return len(stored) == len(provided) && subtle.ConstantTimeCompare(stored, provided[:]) == 1
}

// randomToken creates an URL-safe cryptographic bearer token.
func randomToken(size int) (string, error) {
	data := make([]byte, size)
	if _, err := rand.Read(data); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(data), nil
}
