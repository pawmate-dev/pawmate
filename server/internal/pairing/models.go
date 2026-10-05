package pairing

import (
	"time"

	"gorm.io/gorm"
)

// pairingRecord maps the existing singleton schema without changing stored hashes.
type pairingRecord struct {
	ID                  int `gorm:"primaryKey;autoIncrement:false"`
	ServerURL           string
	InviteCodeHash      []byte
	InviteExpiresAt     int64
	InviterTokenHash    []byte
	InviterRecoveryHash []byte
	PairID              *string
	InviteeTokenHash    []byte
	InviteeRecoveryHash []byte
	Paired              bool
}

// TableName preserves the singular table name used by existing installations.
func (pairingRecord) TableName() string { return "pairing_state" }

// deviceRecord stores a device's hashed token and legacy Unix-second timestamp.
type deviceRecord struct {
	ID        string `gorm:"primaryKey"`
	Role      string
	TokenHash []byte
	Name      string
	CreatedAt int64 `gorm:"autoCreateTime:false"`
}

// TableName preserves the existing device-session table.
func (deviceRecord) TableName() string { return "device_sessions" }

// deviceCodeRecord stores only a digest of a short-lived device login code.
type deviceCodeRecord struct {
	CodeHash  []byte `gorm:"primaryKey"`
	Role      string
	IssuerID  string
	ExpiresAt int64
}

// TableName preserves the existing login-code table and its cascading foreign key.
func (deviceCodeRecord) TableName() string { return "device_login_codes" }

// deviceMigration records the completed legacy-token import.
type deviceMigration struct {
	Version int `gorm:"primaryKey;autoIncrement:false"`
}

// TableName preserves the durable marker that prevents revoked token resurrection.
func (deviceMigration) TableName() string { return "device_migrations" }

// messageRecord separates SQLite millisecond timestamps from the public API model.
type messageRecord struct {
	ID        int64 `gorm:"primaryKey;autoIncrement"`
	PairID    string
	Sender    string
	ClientID  string
	Text      string
	CreatedAt int64 `gorm:"autoCreateTime:false"`
}

// TableName preserves the persisted chat history table.
func (messageRecord) TableName() string { return "chat_messages" }

// message converts storage timestamps without exposing storage-only pair metadata.
func (record messageRecord) message() Message {
	return Message{ID: record.ID, ClientID: record.ClientID, Sender: record.Sender,
		Text: record.Text, CreatedAt: time.UnixMilli(record.CreatedAt).UTC()}
}

// readRecord maps the composite member-level read-cursor key.
type readRecord struct {
	PairID    string `gorm:"primaryKey"`
	Role      string `gorm:"primaryKey"`
	MessageID int64
}

// TableName preserves the existing read-receipt table.
func (readRecord) TableName() string { return "chat_reads" }

// migrateSchema creates only missing tables/indexes; it never rebuilds old tables.
// Explicit DDL preserves singleton checks, idempotency keys, foreign keys and
// INTEGER timestamps. Future schema changes should use reviewed versioned SQL,
// not AutoMigrate on a live private instance.
func migrateSchema(db *gorm.DB) error {
	return db.Transaction(func(tx *gorm.DB) error {
		for _, schema := range []string{
			`CREATE TABLE IF NOT EXISTS member_profiles (
				role TEXT PRIMARY KEY CHECK(role IN ('inviter','invitee')),
				nickname TEXT NOT NULL, avatar_base64 TEXT NOT NULL
			)`,
			`CREATE TABLE IF NOT EXISTS pairing_state (
				id INTEGER PRIMARY KEY CHECK (id = 1), server_url TEXT NOT NULL,
				invite_code_hash BLOB NOT NULL, invite_expires_at INTEGER NOT NULL,
				inviter_token_hash BLOB NOT NULL, inviter_recovery_hash BLOB NOT NULL,
				pair_id TEXT, invitee_token_hash BLOB, invitee_recovery_hash BLOB,
				paired INTEGER NOT NULL DEFAULT 0
			)`,
			`CREATE TABLE IF NOT EXISTS device_sessions (
				id TEXT PRIMARY KEY, role TEXT NOT NULL CHECK(role IN ('inviter','invitee')),
				token_hash BLOB NOT NULL UNIQUE, name TEXT NOT NULL, created_at INTEGER NOT NULL
			)`,
			`CREATE TABLE IF NOT EXISTS device_login_codes (
				code_hash BLOB PRIMARY KEY, role TEXT NOT NULL, issuer_id TEXT NOT NULL,
				expires_at INTEGER NOT NULL,
				FOREIGN KEY(issuer_id) REFERENCES device_sessions(id) ON DELETE CASCADE
			)`,
			`CREATE TABLE IF NOT EXISTS device_migrations (version INTEGER PRIMARY KEY)`,
			`CREATE TABLE IF NOT EXISTS chat_messages (
				id INTEGER PRIMARY KEY AUTOINCREMENT, pair_id TEXT NOT NULL,
				sender TEXT NOT NULL CHECK(sender IN ('inviter','invitee')),
				client_id TEXT NOT NULL, text TEXT NOT NULL, created_at INTEGER NOT NULL,
				UNIQUE(pair_id, sender, client_id)
			)`,
			`CREATE INDEX IF NOT EXISTS chat_messages_pair_id ON chat_messages(pair_id, id)`,
			`CREATE TABLE IF NOT EXISTS chat_attachments (
				message_id INTEGER PRIMARY KEY REFERENCES chat_messages(id) ON DELETE CASCADE,
				kind TEXT NOT NULL CHECK(kind IN ('file','image')), name TEXT NOT NULL,
				content_type TEXT NOT NULL, size INTEGER NOT NULL, sha256 TEXT NOT NULL, data BLOB NOT NULL
			)`,
			`CREATE TABLE IF NOT EXISTS chat_reads (
				pair_id TEXT NOT NULL, role TEXT NOT NULL,
				message_id INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(pair_id, role)
			)`,
		} {
			if err := tx.Exec(schema).Error; err != nil {
				return err
			}
		}
		return nil
	})
}
