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

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
	"gorm.io/gorm/logger"
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
	PairID   string
	Role     string
	Status   string
	DeviceID string
}

// Service stores the single couple relationship for one private instance.
type Service struct {
	db  *gorm.DB
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
	// Reuse modernc's pure-Go connection rather than the dialector's CGO default.
	orm, err := gorm.Open(sqlite.New(sqlite.Config{DriverName: "sqlite", Conn: db}), &gorm.Config{
		// SQL tracing could expose private messages, names or credential digests.
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		db.Close()
		return nil, fmt.Errorf("open pairing ORM: %w", err)
	}
	if err := migrateSchema(orm); err != nil {
		db.Close()
		return nil, fmt.Errorf("create pairing schema: %w", err)
	}
	service := &Service{db: orm, now: time.Now}
	if err := service.migrateDevices(); err != nil {
		db.Close()
		return nil, err
	}
	return service, nil
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
	db, err := service.db.DB()
	if err != nil {
		return err
	}
	return db.Close()
}

// CreateInvite creates one expiring invitation for the instance.
func (service *Service) CreateInvite(serverURL string, deviceNames ...string) (Invite, error) {
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

	err = service.db.Transaction(func(tx *gorm.DB) error {
		var existing pairingRecord
		err := tx.Take(&existing, "id = ?", 1).Error
		switch {
		case err == nil && existing.Paired:
			return ErrAlreadyPaired
		case err == nil && service.now().Unix() < existing.InviteExpiresAt:
			return ErrInvitePending
		case err != nil && !errors.Is(err, gorm.ErrRecordNotFound):
			return fmt.Errorf("read pairing state: %w", err)
		}
		record := pairingRecord{ID: 1, ServerURL: baseURL, InviteCodeHash: codeHash[:],
			InviteExpiresAt: expiresAt.Unix(), InviterTokenHash: inviterTokenHash[:],
			InviterRecoveryHash: inviterRecoveryHash[:]}
		// Explicit columns include zero/NULL values when replacing an expired invite.
		if err := tx.Clauses(clause.OnConflict{Columns: []clause.Column{{Name: "id"}},
			DoUpdates: clause.AssignmentColumns([]string{"server_url", "invite_code_hash", "invite_expires_at",
				"inviter_token_hash", "inviter_recovery_hash", "pair_id", "invitee_token_hash", "invitee_recovery_hash", "paired"}),
		}).Create(&record).Error; err != nil {
			return fmt.Errorf("save pairing invitation: %w", err)
		}
		// An expired, unpaired invitation starts a new identity and device set.
		if err := tx.Where("1 = 1").Delete(&deviceCodeRecord{}).Error; err != nil {
			return err
		}
		if err := tx.Where("1 = 1").Delete(&deviceRecord{}).Error; err != nil {
			return err
		}
		_, err = service.insertDevice(tx, "inviter", inviterToken, deviceName(deviceNames))
		return err
	})
	if err != nil {
		return Invite{}, err
	}

	return Invite{
		URL:          "pawmate://pair?server=" + url.QueryEscape(baseURL) + "&code=" + url.QueryEscape(code),
		InviterToken: inviterToken,
		RecoveryCode: inviterRecovery,
		ExpiresAt:    expiresAt,
	}, nil
}

// RedeemInvite atomically consumes an invite and creates the instance pair.
func (service *Service) RedeemInvite(code string, deviceNames ...string) (PairingStatus, error) {
	service.mu.Lock()
	defer service.mu.Unlock()

	var state pairingRecord
	err := service.db.Take(&state, "id = ?", 1).Error
	if errors.Is(err, gorm.ErrRecordNotFound) || state.Paired {
		return PairingStatus{}, ErrInvalidInvite
	}
	if err != nil {
		return PairingStatus{}, fmt.Errorf("read pairing invitation: %w", err)
	}
	if service.now().Unix() >= state.InviteExpiresAt {
		return PairingStatus{}, ErrExpiredInvite
	}
	if !sameHash(state.InviteCodeHash, tokenHash(strings.TrimSpace(code))) {
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
	err = service.db.Transaction(func(tx *gorm.DB) error {
		result := tx.Model(&pairingRecord{}).
			Where("id = ? AND paired = ? AND invite_code_hash = ? AND invite_expires_at > ?", 1, false, state.InviteCodeHash, service.now().Unix()).
			Updates(map[string]any{"pair_id": pairID, "invitee_token_hash": inviteeTokenHash[:],
				"invitee_recovery_hash": inviteeRecoveryHash[:], "paired": true})
		if result.Error != nil {
			return fmt.Errorf("complete pairing: %w", result.Error)
		}
		if result.RowsAffected != 1 {
			return ErrInvalidInvite
		}
		_, err := service.insertDevice(tx, "invitee", inviteeToken, deviceName(deviceNames))
		return err
	})
	if err != nil {
		return PairingStatus{}, err
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
	session, err := service.Authenticate(inviterToken)
	if errors.Is(err, ErrInvalidSessionToken) || (err == nil && session.Role != "inviter") {
		return PairingStatus{}, ErrInvalidInviterToken
	}
	if err != nil {
		return PairingStatus{}, err
	}
	return PairingStatus{PairID: session.PairID, Status: session.Status}, nil
}

// Authenticate validates either member's access token and returns its session.
func (service *Service) Authenticate(accessToken string) (Session, error) {
	service.mu.Lock()
	defer service.mu.Unlock()
	return service.authenticateDevice(accessToken)
}

// authenticateDevice reads a device session while the caller holds the mutex.
func (service *Service) authenticateDevice(accessToken string) (Session, error) {
	var record struct {
		Paired   bool
		PairID   string
		DeviceID string
		Role     string
	}
	hash := tokenHash(strings.TrimSpace(accessToken))
	err := service.db.Table("device_sessions AS d").
		Select("p.paired, p.pair_id, d.id AS device_id, d.role").
		Joins("JOIN pairing_state AS p ON p.id = 1").Where("d.token_hash = ?", hash[:]).Take(&record).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return Session{}, ErrInvalidSessionToken
	}
	if err != nil {
		return Session{}, fmt.Errorf("read pairing session: %w", err)
	}

	session := Session{PairID: record.PairID, DeviceID: record.DeviceID, Role: record.Role, Status: "pending"}
	if record.Paired {
		session.Status = "paired"
	}
	return session, nil
}

// Recover rotates one member's credentials using their single-use recovery code.
func (service *Service) Recover(recoveryCode string, deviceNames ...string) (RecoveredCredentials, error) {
	service.mu.Lock()
	defer service.mu.Unlock()

	var state pairingRecord
	err := service.db.Take(&state, "id = ?", 1).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return RecoveredCredentials{}, ErrNotPaired
	}
	if err != nil {
		return RecoveredCredentials{}, fmt.Errorf("read recovery state: %w", err)
	}
	if !state.Paired || state.PairID == nil {
		return RecoveredCredentials{}, ErrNotPaired
	}

	providedHash := tokenHash(strings.TrimSpace(recoveryCode))
	role := ""
	if sameHash(state.InviterRecoveryHash, providedHash) {
		role = "inviter"
	} else if sameHash(state.InviteeRecoveryHash, providedHash) {
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
	accessTokenHash := tokenHash(accessToken)
	newRecoveryHash := tokenHash(newRecoveryCode)
	err = service.db.Transaction(func(tx *gorm.DB) error {
		// Column names are selected internally, never taken from client input.
		result := tx.Model(&pairingRecord{}).Where("id = ? AND paired = ?", 1, true).
			Where(recoveryColumn+" = ?", providedHash[:]).
			Updates(map[string]any{tokenColumn: accessTokenHash[:], recoveryColumn: newRecoveryHash[:]})
		if result.Error != nil {
			return fmt.Errorf("rotate recovered credentials: %w", result.Error)
		}
		if result.RowsAffected != 1 {
			return ErrInvalidRecoveryCode
		}
		// Recovery remains an emergency reset. Normal device login is additive.
		if err := tx.Where("role = ?", role).Delete(&deviceRecord{}).Error; err != nil {
			return err
		}
		if err := tx.Where("role = ?", role).Delete(&deviceCodeRecord{}).Error; err != nil {
			return err
		}
		_, err := service.insertDevice(tx, role, accessToken, deviceName(deviceNames))
		return err
	})
	if err != nil {
		return RecoveredCredentials{}, err
	}
	return RecoveredCredentials{
		PairID:       *state.PairID,
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
