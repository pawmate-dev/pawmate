package pairing

import (
	"errors"
	"path/filepath"
	"sync"
	"testing"
	"time"
)

func pairedDevices(t *testing.T, service *Service) (Invite, PairingStatus) {
	t.Helper()
	invite, err := service.CreateInvite("https://home.example.test", "Phone")
	if err != nil {
		t.Fatal(err)
	}
	partner, err := service.RedeemInvite(inviteCode(t, invite.URL), "Partner phone")
	if err != nil {
		t.Fatal(err)
	}
	return invite, partner
}

func TestAdditionalDevicesRemainAuthenticatedAfterRestart(t *testing.T) {
	path := filepath.Join(t.TempDir(), "pawmate.db")
	service, err := OpenService(path)
	if err != nil {
		t.Fatal(err)
	}
	invite, partner := pairedDevices(t, service)
	tokens := []string{invite.InviterToken, partner.InviteeToken}
	for _, name := range []string{"Tablet", "Computer"} {
		code, err := service.CreateDeviceLoginCode(invite.InviterToken)
		if err != nil {
			t.Fatal(err)
		}
		credentials, err := service.RedeemDeviceLoginCode(code.Code, name)
		if err != nil {
			t.Fatal(err)
		}
		if credentials.PairID != partner.PairID || credentials.Role != "inviter" {
			t.Fatal("new device changed member identity")
		}
		tokens = append(tokens, credentials.AccessToken)
		if _, err := service.RedeemDeviceLoginCode(code.Code, "Again"); !errors.Is(err, ErrInvalidDeviceCode) {
			t.Fatalf("replay error: %v", err)
		}
	}
	if err := service.Close(); err != nil {
		t.Fatal(err)
	}
	service, err = OpenService(path)
	if err != nil {
		t.Fatal(err)
	}
	defer service.Close()
	for _, token := range tokens {
		if session, err := service.Authenticate(token); err != nil || session.Status != "paired" {
			t.Fatalf("device lost login: %v", err)
		}
	}
	devices, err := service.Devices(tokens[2])
	if err != nil || len(devices) != 3 {
		t.Fatalf("devices = %v, error = %v", devices, err)
	}
	current := 0
	for _, device := range devices {
		if device.Current {
			current++
		}
	}
	if current != 1 {
		t.Fatal("device list did not identify the current device")
	}
	// Adding devices does not consume or rotate the member recovery code.
	if _, err := service.Recover(invite.RecoveryCode); err != nil {
		t.Fatal(err)
	}
	for _, token := range []string{tokens[0], tokens[2], tokens[3]} {
		if _, err := service.Authenticate(token); !errors.Is(err, ErrInvalidSessionToken) {
			t.Fatalf("recovery left an old device active: %v", err)
		}
	}
	if _, err := service.Authenticate(partner.InviteeToken); err != nil {
		t.Fatal("recovery affected the partner")
	}
}

func TestDeviceRevocationIsMemberScopedAndInvalidatesIssuedCodes(t *testing.T) {
	service := NewService()
	defer service.Close()
	invite, partner := pairedDevices(t, service)
	code, _ := service.CreateDeviceLoginCode(invite.InviterToken)
	computer, err := service.RedeemDeviceLoginCode(code.Code, "Computer")
	if err != nil {
		t.Fatal(err)
	}
	phone, _ := service.Authenticate(invite.InviterToken)
	if err := service.RevokeDevice(partner.InviteeToken, phone.DeviceID); !errors.Is(err, ErrDeviceNotFound) {
		t.Fatalf("partner can revoke own member's device: %v", err)
	}
	pending, err := service.CreateDeviceLoginCode(invite.InviterToken)
	if err != nil {
		t.Fatal(err)
	}
	if err := service.RevokeDevice(computer.AccessToken, phone.DeviceID); err != nil {
		t.Fatal(err)
	}
	if _, err := service.Authenticate(invite.InviterToken); !errors.Is(err, ErrInvalidSessionToken) {
		t.Fatalf("revoked token accepted: %v", err)
	}
	if _, err := service.RedeemDeviceLoginCode(pending.Code, "Tablet"); !errors.Is(err, ErrInvalidDeviceCode) {
		t.Fatalf("revoked device's code accepted: %v", err)
	}
	if _, err := service.Authenticate(computer.AccessToken); err != nil {
		t.Fatal(err)
	}
}

func TestDeviceLoginCodeExpiryAndConcurrentConsumption(t *testing.T) {
	service := NewService()
	defer service.Close()
	clock := time.Now()
	service.now = func() time.Time { return clock }
	invite, _ := pairedDevices(t, service)
	code, err := service.CreateDeviceLoginCode(invite.InviterToken)
	if err != nil {
		t.Fatal(err)
	}
	clock = code.ExpiresAt
	if _, err := service.RedeemDeviceLoginCode(code.Code, "Tablet"); !errors.Is(err, ErrInvalidDeviceCode) {
		t.Fatalf("expired code accepted: %v", err)
	}
	code, err = service.CreateDeviceLoginCode(invite.InviterToken)
	if err != nil {
		t.Fatal(err)
	}
	var wg sync.WaitGroup
	results := make(chan error, 2)
	for i := 0; i < 2; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			_, err := service.RedeemDeviceLoginCode(code.Code, "Computer")
			results <- err
		}()
	}
	wg.Wait()
	close(results)
	successes := 0
	for err := range results {
		if err == nil {
			successes++
		} else if !errors.Is(err, ErrInvalidDeviceCode) {
			t.Fatal(err)
		}
	}
	if successes != 1 {
		t.Fatalf("code redeemed %d times", successes)
	}
}

func TestLegacyTokenMigrationDoesNotRestoreRevokedDevice(t *testing.T) {
	path := filepath.Join(t.TempDir(), "legacy.db")
	service, err := OpenService(path)
	if err != nil {
		t.Fatal(err)
	}
	invite, partner := pairedDevices(t, service)
	// Remove only the new tables to reproduce the previous release's database.
	for _, table := range []string{"device_login_codes", "device_sessions", "device_migrations"} {
		if err := service.db.Exec("DROP TABLE " + table).Error; err != nil {
			t.Fatal(err)
		}
	}
	service.Close()
	service, err = OpenService(path)
	if err != nil {
		t.Fatal(err)
	}
	for _, token := range []string{invite.InviterToken, partner.InviteeToken} {
		if _, err := service.Authenticate(token); err != nil {
			t.Fatal("migration rejected existing token", err)
		}
	}
	code, _ := service.CreateDeviceLoginCode(invite.InviterToken)
	computer, err := service.RedeemDeviceLoginCode(code.Code, "Computer")
	if err != nil {
		t.Fatal(err)
	}
	if err := service.RevokeDevice(computer.AccessToken, "legacy-inviter"); err != nil {
		t.Fatal(err)
	}
	service.Close()
	service, err = OpenService(path)
	if err != nil {
		t.Fatal(err)
	}
	defer service.Close()
	if _, err := service.Authenticate(invite.InviterToken); !errors.Is(err, ErrInvalidSessionToken) {
		t.Fatalf("restart restored revoked legacy token: %v", err)
	}
	if _, err := service.Authenticate(computer.AccessToken); err != nil {
		t.Fatal(err)
	}
}
