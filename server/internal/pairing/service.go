package pairing

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"net/url"
	"strings"
	"sync"
	"time"
)

var (
	ErrAlreadyPaired       = errors.New("instance is already paired")
	ErrInvitePending       = errors.New("an invitation is already pending")
	ErrInvalidInvite       = errors.New("invite is invalid")
	ErrExpiredInvite       = errors.New("invite has expired")
	ErrInvalidInviterToken = errors.New("inviter token is invalid")
	ErrInvalidServerURL    = errors.New("server URL is invalid")
)

const inviteTTL = 10 * time.Minute

// Invite is the one-time invitation returned to the inviting client.
type Invite struct {
	URL          string
	InviterToken string
	ExpiresAt    time.Time
}

// PairingStatus describes the state visible to the inviting client.
type PairingStatus struct {
	PairID       string
	Status       string
	InviteeToken string
}

// Service is the development pairing state for one private Pawmate instance.
// It is intentionally in-memory until the SQLite persistence chapter is implemented.
type Service struct {
	mu     sync.Mutex
	now    func() time.Time
	invite *inviteState
	paired bool
}

type inviteState struct {
	codeHash     [sha256.Size]byte
	expiresAt    time.Time
	inviterToken string
	pairID       string
	inviteeToken string
}

// NewService creates process-local pairing state for one server instance.
func NewService() *Service {
	// The service is process-local for this first development slice.
	return &Service{now: time.Now}
}

// CreateInvite creates one expiring invite for the instance.
func (service *Service) CreateInvite(serverURL string) (Invite, error) {
	baseURL, err := normalizeServerURL(serverURL)
	if err != nil {
		return Invite{}, err
	}

	service.mu.Lock()
	defer service.mu.Unlock()
	if service.paired {
		return Invite{}, ErrAlreadyPaired
	}
	if service.invite != nil && service.now().Before(service.invite.expiresAt) {
		return Invite{}, ErrInvitePending
	}

	code, err := randomToken(32)
	if err != nil {
		return Invite{}, err
	}
	inviterToken, err := randomToken(32)
	if err != nil {
		return Invite{}, err
	}
	expiresAt := service.now().Add(inviteTTL)
	state := &inviteState{
		codeHash:     sha256.Sum256([]byte(code)),
		expiresAt:    expiresAt,
		inviterToken: inviterToken,
	}
	service.invite = state

	return Invite{
		URL:          "pawmate://pair?server=" + url.QueryEscape(baseURL) + "&code=" + url.QueryEscape(code),
		InviterToken: inviterToken,
		ExpiresAt:    expiresAt,
	}, nil
}

// RedeemInvite atomically consumes an invite and creates the instance pair.
func (service *Service) RedeemInvite(code string) (PairingStatus, error) {
	service.mu.Lock()
	defer service.mu.Unlock()

	if service.paired || service.invite == nil {
		return PairingStatus{}, ErrInvalidInvite
	}
	if !service.now().Before(service.invite.expiresAt) {
		return PairingStatus{}, ErrExpiredInvite
	}
	if service.invite.codeHash != sha256.Sum256([]byte(strings.TrimSpace(code))) {
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
	service.invite.pairID = pairID
	service.invite.inviteeToken = inviteeToken
	service.paired = true

	return PairingStatus{PairID: pairID, Status: "paired", InviteeToken: inviteeToken}, nil
}

// Status returns pairing state for the inviting client.
func (service *Service) Status(inviterToken string) (PairingStatus, error) {
	service.mu.Lock()
	defer service.mu.Unlock()

	if service.invite == nil || service.invite.inviterToken != inviterToken {
		return PairingStatus{}, ErrInvalidInviterToken
	}
	if !service.paired {
		return PairingStatus{Status: "pending"}, nil
	}
	return PairingStatus{
		PairID: service.invite.pairID,
		Status: "paired",
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

// randomToken creates an URL-safe cryptographic bearer token.
func randomToken(size int) (string, error) {
	data := make([]byte, size)
	if _, err := rand.Read(data); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(data), nil
}
