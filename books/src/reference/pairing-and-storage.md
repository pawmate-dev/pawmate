# Pairing service and persistence

## Service boundaries

The Gin HTTP layer validates request shape, derives authenticated identity from
the bearer token, calls the pairing domain service, and maps domain outcomes to
HTTP responses. Pairing rules and transaction boundaries live in the service
layer rather than in handlers.

The service enforces one couple per private instance and prevents a member from
joining or creating a second relationship. Invitation acceptance atomically
checks the code, expiry, redemption state, inviter and invitee eligibility,
stores both profiles and credentials, and marks the invitation redeemed. A
failed operation leaves the invitation and pair state unchanged.

## Credential lifecycle

Invitation codes, recovery codes, device login codes, and access tokens are
bearer credentials. The database retains hashes rather than reusable plaintext
values. Invitation and device login codes expire after ten minutes and are
single-use. Recovery replaces the member's credential set and revokes their
other sessions; device login adds a session without changing recovery access.

The session endpoint validates the presented device token and returns the
member's role, pair identifier, profile, and partner profile when paired. A
revoked token receives HTTP 401. The Flutter client treats that response as an
invalid session, while connection failures remain retryable.

## SQLite storage

GORM models represent pairing, profiles, device sessions, login codes, chat
messages, and read cursors. They remain separate from HTTP response types. The
official SQLite dialector uses the existing pure-Go SQLite connection.

Schema updates are additive SQL migrations that preserve existing table names,
constraints, identifiers, and timestamp units. Startup does not run GORM
`AutoMigrate` against an existing private database. Multi-step credential,
pairing, device-code, and read-cursor operations use explicit transactions.
SQL tracing is disabled to keep credential digests and private content out of
logs. Database backups should be taken before server upgrades and stored
securely.
