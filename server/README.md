# Pawmate server

Gin HTTP API for a private Pawmate instance. It exposes instance discovery and
the first two-person pairing flow. Pairing state is persisted in SQLite.

## Run locally

```bash
go run ./cmd/pawmate-server
```

The server listens on `http://localhost:8080` by default.

```bash
curl http://localhost:8080/healthz
curl http://localhost:8080/api/v1/instance
```

The pairing API exposes:

```text
POST /api/v1/pairing/invites
GET  /api/v1/pairing/invites/status
POST /api/v1/pairing/invites/redeem
POST /api/v1/pairing/recover
GET  /api/v1/pairing/session
GET  /api/v1/chat/messages
POST /api/v1/chat/messages
POST /api/v1/chat/read
GET  /api/v1/pairing/devices
DELETE /api/v1/pairing/devices/:id
POST /api/v1/pairing/devices/login-codes
POST /api/v1/pairing/devices/login-codes/redeem
```

Create an invitation by sending the configured server URL:

```bash
curl -X POST http://localhost:8080/api/v1/pairing/invites \
  -H 'content-type: application/json' \
  -d '{"server_url":"http://localhost:8080"}'
```

The response contains a one-time `invite_url`, an `inviter_token` for status
checks, and a `recovery_code`. The invitee opens the custom link in Pawmate and
accepts it; the app redeems the code and receives that member's access token and
recovery code. Invitation codes expire after ten minutes and can be redeemed
only once.

Pairing state is stored in `pawmate.db` in the server's current working
directory. Override the path with `PAWMATE_DATABASE_PATH`. The database stores
SHA-256 hashes of invitation codes, access tokens, and recovery codes rather
than their raw values. Keep the database on persistent storage and include it
in server backups. Stop the server before copying the database file.

Each member should save their recovery code outside the app. After reinstall,
enter the same server URL and recovery code in the restore section. The server
revokes all of that member's device sessions and outstanding device login codes,
then issues a new access token and recovery code. The old recovery code can no
longer be used. The partner's sessions remain active. Recovery is for lost access;
use a device login code to add a device while keeping existing devices signed in.
A recovery code belongs to one member; the two members should keep separate codes.

On app startup, the client calls `GET /api/v1/pairing/session` with its saved
bearer token. The endpoint accepts any active device token and returns
the role, pair ID, and pairing state. Invalid or revoked tokens receive HTTP
401 and should open recovery; network failures should offer retry without
treating the credentials as invalid.

## Sign in on multiple devices

Each phone, tablet, computer, or browser installation has its own access token.
The two members share one pair ID, but each member can have multiple sessions.
The server automatically migrates tokens from the previous single-token schema
on startup, so existing installations remain signed in. Migration runs once;
revoked legacy tokens are never re-imported on restart.

1. On an already signed-in device, open **My devices** on the home page and
   choose **Add a device**.
2. On the new device, choose **Sign in on another device** and enter the same
   server URL, the device login code, and a device name.
3. The new device saves its own token in platform secure storage. Existing
   sessions and the member's recovery code remain unchanged.

`POST /pairing/devices/login-codes` requires a paired device's bearer token.
It returns `code` and `expires_at`. The code expires after ten minutes and can
be redeemed once. Creating another code on the same device replaces its previous
code. The server stores only the code hash.

`POST /pairing/devices/login-codes/redeem` accepts
`{"code":"...","device_name":"My tablet"}` without an access token. It returns
`access_token`, `pair_id`, and `role`; it does not disclose the recovery code.
Keep device login codes private: possession grants access as the issuing member.

`GET /pairing/devices` returns only the authenticated member's devices with
`id`, `name`, `created_at`, and `current`. No tokens or recovery codes are returned.
`DELETE /pairing/devices/:id` removes a session owned by that member and all
login codes it issued. A removed device gets HTTP 401 when it next authenticates.
The Flutter UI allows removing other devices and refreshing the list; it does
not remove the current device. All paths in this section use the `/api/v1` prefix.

Recovery codes are not synchronized between devices. An additional device stores
no recovery code; retain the member's current recovery code outside the app.
Device revocation is enforced on server requests, not through push notifications.

## Text messages and read receipts

The couple space opens on the Chat tab. Text messages and read progress are
persisted in the same SQLite database as pairing and device sessions. Every chat
endpoint requires an active, paired device's Bearer token. The server derives the
pair and sender from that token, never from client-supplied identity fields.

- `POST /api/v1/chat/messages` accepts `client_id` (1–64 bytes) and `text`
  (1–4000 Unicode code points after trimming). Repeating the same member's
  `client_id` returns the original message; changing its text returns HTTP 409.
- `GET /api/v1/chat/messages` returns the most recent 50 messages in ascending
  server-ID order. Use `before_id` for earlier history or `after_id` for forward
  updates; they are mutually exclusive. `limit` must be between 1 and 100.
  `has_more` describes the requested direction's additional pages.
- Every history response includes `latest_id`, `read_id`, `partner_read_id` and
  `unread_count`. Only messages from the other member count as unread.
- `POST /api/v1/chat/read` accepts `message_id`. The ID must belong to this pair.
  A member's read cursor only advances; reading on a tablet also clears the
  corresponding unread messages on that member's phone and computer.

Read receipts are cumulative: acknowledging message N marks earlier messages
read too. The client acknowledges incoming messages only after they are rendered
inside the visible chat viewport while the application is foregrounded. Polling,
opening Home, and receiving a message on a hidden tab do not mark it read.
Outgoing bubbles distinguish sending, failed (retryable), unread and read states.

The first version synchronizes every two seconds while the app is foregrounded,
including receipt-only updates and this member's messages sent from other devices.
It pauses polling in the background and catches up after resume. Unread alerts
are an in-app Chat badge and a content-free reminder on other tabs. OS/background
push notifications, attachment messages and durable offline outboxes are not yet
implemented. Drafts and failed outgoing messages survive tab switches but are
currently kept in memory; confirmed messages survive app and server restarts.

Chat responses use `Cache-Control: no-store`. Message text is stored in SQLite;
include it when protecting and backing up the instance database. This is not
end-to-end encrypted messaging. Requests do not put message text or tokens in URLs
and the request logger does not record message bodies.

For the Android emulator, configure the Flutter client with
`http://10.0.2.2:8080`; `10.0.2.2` maps to the development machine's loopback
interface from inside the emulator.

The Android client accepts HTTP instance URLs in debug and release builds.
HTTP does not provide application-layer transport encryption: use it only on
trusted private networks or through Tailscale. Prefer HTTPS for public instances.
Both participants must be able to reach the instance URL used in invitations.

## Configuration

### Member nicknames and avatars

Creating and accepting invitations now requires a `profile` object alongside
the existing request fields:

```json
{"profile":{"nickname":"Ash","avatar_base64":"<base64-encoded PNG>"}}
```

Nicknames are trimmed and contain 1–32 Unicode characters without control
characters. Avatars must be valid PNG/JPEG images, at most 256 KiB decoded from
base64, with dimensions at most 512×512. The client center-crops selected images
to a 256×256 PNG; source files must be under 10 MiB. The server validates images
and re-encodes them to PNG before saving, stripping metadata.

The additive `member_profiles` table stores one profile per member. Invitation
creation and acceptance save profiles in the same transaction as credentials
and pairing, so rejected uploads cannot consume an invitation. Replacing an
expired, unpaired invitation removes the old inviter identity. Emergency recovery
and device login preserve profiles. Authenticated `GET /api/v1/pairing/session`
returns `profile` and, once paired, `partner`; anonymous callers cannot fetch them.

Existing paired databases remain usable with absent profiles; this change does
not invent nicknames or overwrite an existing relationship. New invitation
requests from older clients without a profile are rejected. Upgrade the server
and client together. Profile editing for existing couples is not implemented yet.

### Persistence architecture

The server uses [GORM](https://gorm.io/docs/) for pairing, device sessions,
device login codes, chat history and read cursors. Storage models live in
`internal/pairing/models.go`, separate from the API response types. Queries bind
client values as parameters; the ORM's SQL logger is disabled to avoid logging
private content or credential digests.

GORM's official SQLite dialector reuses the existing `modernc.org/sqlite`
connection, so the server remains runnable with `CGO_ENABLED=0`. The dialector
has an indirect `go-sqlite3` dependency, but Pawmate does not open that driver.
SQLite still stores only credential hashes, not recoverable plaintext codes.

Existing `pawmate.db` files are reused in place: table names, integer timestamp
units, message IDs, unique constraints and cascading device-code deletion are
unchanged. Reviewed additive SQL creates missing tables/indexes; startup does
not run `AutoMigrate` or rebuild existing tables. The legacy-token import marker
is retained so revoked devices cannot reappear on restart. Multi-step operations
use GORM transactions, including invite acceptance, credential recovery,
device-code redemption and monotonic read-cursor updates.

Back up the database before upgrading. Do not delete it to switch to GORM.

Copy `.env.example` into your process environment before starting the server.
The environment variables control the port, database path, and stable identity
shown to clients. Production instances should set a real HTTPS
`PAWMATE_PUBLIC_URL` and keep the SQLite database on a persistent volume.

## Verify

```bash
go test ./...
```
