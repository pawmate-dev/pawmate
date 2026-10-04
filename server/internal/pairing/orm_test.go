package pairing

import (
	"database/sql"
	"errors"
	"path/filepath"
	"testing"
	"time"
)

// TestORMOpensPreORMDatabase builds a historical fixture without ORM models.
func TestORMOpensPreORMDatabase(t *testing.T) {
	path := filepath.Join(t.TempDir(), "before-gorm.db")
	db, err := sql.Open("sqlite", path)
	if err != nil {
		t.Fatal(err)
	}
	// Keep this snapshot independent of migrateSchema so model/schema drift is caught.
	for _, schema := range []string{
		`CREATE TABLE pairing_state (id INTEGER PRIMARY KEY CHECK(id = 1), server_url TEXT NOT NULL,
		invite_code_hash BLOB NOT NULL, invite_expires_at INTEGER NOT NULL, inviter_token_hash BLOB NOT NULL,
		inviter_recovery_hash BLOB NOT NULL, pair_id TEXT, invitee_token_hash BLOB, invitee_recovery_hash BLOB,
		paired INTEGER NOT NULL DEFAULT 0)`,
		`CREATE TABLE device_sessions (id TEXT PRIMARY KEY, role TEXT NOT NULL CHECK(role IN ('inviter','invitee')),
		token_hash BLOB NOT NULL UNIQUE, name TEXT NOT NULL, created_at INTEGER NOT NULL)`,
		`CREATE TABLE device_login_codes (code_hash BLOB PRIMARY KEY, role TEXT NOT NULL, issuer_id TEXT NOT NULL,
		expires_at INTEGER NOT NULL, FOREIGN KEY(issuer_id) REFERENCES device_sessions(id) ON DELETE CASCADE)`,
		`CREATE TABLE device_migrations (version INTEGER PRIMARY KEY)`,
		`CREATE TABLE chat_messages (id INTEGER PRIMARY KEY AUTOINCREMENT, pair_id TEXT NOT NULL,
		sender TEXT NOT NULL CHECK(sender IN ('inviter','invitee')), client_id TEXT NOT NULL, text TEXT NOT NULL,
		created_at INTEGER NOT NULL, UNIQUE(pair_id, sender, client_id))`,
		`CREATE INDEX chat_messages_pair_id ON chat_messages(pair_id, id)`,
		`CREATE TABLE chat_reads (pair_id TEXT NOT NULL, role TEXT NOT NULL, message_id INTEGER NOT NULL DEFAULT 0,
		PRIMARY KEY(pair_id, role))`,
	} {
		if _, err := db.Exec(schema); err != nil {
			t.Fatal(err)
		}
	}
	inviterHash, inviteeHash := tokenHash("phone-token"), tokenHash("partner-token")
	revokedHash := tokenHash("revoked-legacy-token")
	recoveryHash, codeHash := tokenHash("existing-recovery"), tokenHash("existing-login-code")
	clock := time.Unix(1800000000, 123000000).UTC()
	if _, err := db.Exec(`INSERT INTO pairing_state VALUES(1, ?, ?, ?, ?, ?, ?, ?, ?, 1)`,
		"https://home.example.test", codeHash[:], clock.Unix(), revokedHash[:], recoveryHash[:], "existing-pair", inviteeHash[:], recoveryHash[:]); err != nil {
		t.Fatal(err)
	}
	for _, record := range []struct {
		id, role, name string
		hash           []byte
	}{
		{"phone", "inviter", "Phone", inviterHash[:]}, {"partner", "invitee", "Partner", inviteeHash[:]},
	} {
		if _, err := db.Exec(`INSERT INTO device_sessions VALUES(?, ?, ?, ?, ?)`, record.id, record.role, record.hash, record.name, clock.Unix()); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := db.Exec(`INSERT INTO device_migrations VALUES(1)`); err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(`INSERT INTO device_login_codes VALUES(?, 'inviter', 'phone', ?)`, codeHash[:], clock.Add(inviteTTL).Unix()); err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(`INSERT INTO chat_messages VALUES(41, 'existing-pair', 'invitee', 'old-client-id', '你好', ?)`, clock.UnixMilli()); err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(`INSERT INTO chat_reads VALUES('existing-pair', 'inviter', 41)`); err != nil {
		t.Fatal(err)
	}
	if err := db.Close(); err != nil {
		t.Fatal(err)
	}

	service, err := OpenService(path)
	if err != nil {
		t.Fatal(err)
	}
	defer service.Close()
	service.now = func() time.Time { return clock }
	for _, token := range []string{"phone-token", "partner-token"} {
		session, err := service.Authenticate(token)
		if err != nil || session.PairID != "existing-pair" {
			t.Fatalf("existing login lost: %v", err)
		}
	}
	if _, err := service.Authenticate("revoked-legacy-token"); !errors.Is(err, ErrInvalidSessionToken) {
		t.Fatalf("revoked token restored: %v", err)
	}
	page, err := service.Messages("phone-token", 0, 0, 20)
	if err != nil || len(page.Messages) != 1 || page.ReadID != 41 || page.UnreadCount != 0 {
		t.Fatalf("existing history lost: %+v, %v", page, err)
	}
	if page.Messages[0].Text != "你好" || !page.Messages[0].CreatedAt.Equal(clock) {
		t.Fatal("message text/timestamp changed")
	}
	devices, err := service.Devices("phone-token")
	if err != nil || len(devices) != 1 || devices[0].CreatedAt.Unix() != clock.Unix() {
		t.Fatalf("device timestamp changed: %v", err)
	}
	message, err := service.SendMessage("phone-token", "new-client-id", "hello")
	if err != nil || message.ID <= 41 {
		t.Fatalf("sequence did not continue: %+v, %v", message, err)
	}
	if _, err := service.RedeemDeviceLoginCode("existing-login-code", "Tablet"); err != nil {
		t.Fatal("existing device code lost", err)
	}
	if _, err := service.Recover("existing-recovery"); err != nil {
		t.Fatal("existing recovery code lost", err)
	}
}

// TestORMRecoveryRollsBackDeviceFailure verifies rotation and revocation are atomic.
func TestORMRecoveryRollsBackDeviceFailure(t *testing.T) {
	service := NewService()
	defer service.Close()
	invite, partner := pairedDevices(t, service)
	code, err := service.CreateDeviceLoginCode(invite.InviterToken)
	if err != nil {
		t.Fatal(err)
	}
	// Inject a storage failure after hashes rotate and previous devices are removed.
	if err := service.db.Exec(`CREATE TRIGGER reject_device BEFORE INSERT ON device_sessions
		BEGIN SELECT RAISE(ABORT, 'injected failure'); END`).Error; err != nil {
		t.Fatal(err)
	}
	if _, err := service.Recover(invite.RecoveryCode); err == nil {
		t.Fatal("expected storage failure")
	}
	for _, token := range []string{invite.InviterToken, partner.InviteeToken} {
		if _, err := service.Authenticate(token); err != nil {
			t.Fatal("rollback lost an existing session", err)
		}
	}
	if err := service.db.Exec(`DROP TRIGGER reject_device`).Error; err != nil {
		t.Fatal(err)
	}
	if _, err := service.RedeemDeviceLoginCode(code.Code, "Tablet"); err != nil {
		t.Fatal("rollback lost outstanding code", err)
	}
	if _, err := service.Recover(invite.RecoveryCode); err != nil {
		t.Fatal("rollback consumed recovery code", err)
	}
}

// TestORMExpiredInviteReplacement verifies zero/NULL fields and identity reset.
func TestORMExpiredInviteReplacement(t *testing.T) {
	service := NewService()
	defer service.Close()
	clock := time.Now()
	service.now = func() time.Time { return clock }
	old, err := service.CreateInvite("http://localhost:8080")
	if err != nil {
		t.Fatal(err)
	}
	clock = old.ExpiresAt
	fresh, err := service.CreateInvite("http://localhost:8081")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := service.Authenticate(old.InviterToken); !errors.Is(err, ErrInvalidSessionToken) {
		t.Fatalf("old inviter still active: %v", err)
	}
	session, err := service.Authenticate(fresh.InviterToken)
	if err != nil || session.Status != "pending" || session.PairID != "" {
		t.Fatalf("bad pending state: %+v, %v", session, err)
	}
	if _, err := service.RedeemInvite(inviteCode(t, old.URL)); !errors.Is(err, ErrInvalidInvite) {
		t.Fatalf("old link still accepted: %v", err)
	}
	if _, err := service.RedeemInvite(inviteCode(t, fresh.URL)); err != nil {
		t.Fatal(err)
	}
}
