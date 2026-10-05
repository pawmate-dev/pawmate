package pairing

import (
	"errors"
	"net/url"
	"testing"
	"time"
)

func TestInviteCanBeRedeemedOnlyOnce(t *testing.T) {
	service := NewService()
	invite, err := service.CreateInvite("https://home.example.test")
	if err != nil {
		t.Fatal(err)
	}

	code := inviteCode(t, invite.URL)
	status, err := service.RedeemInvite(code)
	if err != nil {
		t.Fatal(err)
	}
	if status.Status != "paired" || status.PairID == "" || status.InviteeToken == "" {
		t.Fatalf("unexpected pairing status: %+v", status)
	}
	if _, err := service.RedeemInvite(code); !errors.Is(err, ErrInvalidInvite) {
		t.Fatalf("second redemption error = %v, want ErrInvalidInvite", err)
	}
}

func TestInstanceAllowsOnlyOnePendingInvite(t *testing.T) {
	service := NewService()
	if _, err := service.CreateInvite("http://localhost:8080/"); err != nil {
		t.Fatal(err)
	}
	if _, err := service.CreateInvite("http://localhost:8080"); !errors.Is(err, ErrInvitePending) {
		t.Fatalf("second invite error = %v, want ErrInvitePending", err)
	}
}

func TestExpiredInviteCannotBeRedeemed(t *testing.T) {
	service := NewService()
	clock := time.Now()
	service.now = func() time.Time { return clock }
	invite, err := service.CreateInvite("https://home.example.test")
	if err != nil {
		t.Fatal(err)
	}
	clock = invite.ExpiresAt
	if _, err := service.RedeemInvite(inviteCode(t, invite.URL)); !errors.Is(err, ErrExpiredInvite) {
		t.Fatalf("redemption error = %v, want ErrExpiredInvite", err)
	}
}

func TestServerURLMustNotContainCredentialsOrQuery(t *testing.T) {
	service := NewService()
	for _, rawURL := range []string{
		"https://user:password@example.test",
		"https://example.test?redirect=other",
		"ftp://example.test",
	} {
		if _, err := service.CreateInvite(rawURL); !errors.Is(err, ErrInvalidServerURL) {
			t.Fatalf("CreateInvite(%q) error = %v, want ErrInvalidServerURL", rawURL, err)
		}
	}
}

func inviteCode(t *testing.T, rawURL string) string {
	t.Helper()
	parsed, err := url.Parse(rawURL)
	if err != nil {
		t.Fatal(err)
	}
	return parsed.Query().Get("code")
}
