# Current foundation

The repository currently contains two applications:

| Area           | Location        | Current responsibility             |
| -------------- | --------------- | ---------------------------------- |
| Flutter client | repository root | Android-ready Pawmate client shell |
| Gin server     | `server/`       | Private-instance discovery and pairing API |

The Gin server already exposes these unauthenticated discovery endpoints:

```text
GET /healthz
GET /api/v1/instance
```

`GET /api/v1/instance` is the first contract between the client and a private
Pawmate instance. It reports an instance identifier, display name, API version,
public URL when configured, and the currently advertised features.

The Flutter client supports the inviter's server setup, invitation creation,
status checks, accepting an invitation opened through the Android
`pawmate://pair` scheme, and restoring a member after reinstall with a recovery
code. On startup, valid paired credentials lead to the couple home, invalid
credentials lead to recovery, and network errors remain retryable. The Gin
service persists the single couple relationship in SQLite and exposes a
session-validation endpoint. Each member can stay signed in on multiple devices,
with an independent access token for each installation. Existing token records
are automatically migrated on server startup.

To add a phone, tablet or computer, use **My devices → Add a device** on an
already signed-in device. On the new installation, choose **Sign in on another
device** and enter the same server URL, the one-time device login code, and a
device name. Device login codes expire after ten minutes and do not change the
member's recovery code or sign out existing devices. The home screen also lists
the current member's devices and allows signing out another device. It never
lists or removes the partner's devices.

The couple space now opens on the **Chat** tab, followed by **Play** and **Home**.
The first chat slice supports persisted text messages, earlier history pages,
cross-device synchronization, failed-send retries, read receipts and unread
reminders. Device management and recovery notes live in Home; Play is a placeholder.

Messages use a server sequence ID and a client-generated idempotency ID. Retrying
the same send cannot create a duplicate, even if its first response was lost.
Read progress belongs to a member rather than a device: reading on one of your
devices updates your other devices and the partner's read labels. Only rendered
incoming messages inside the foreground chat viewport advance the read cursor.
Scrolling older history does not acknowledge newer messages outside the viewport.

Foreground synchronization currently polls every two seconds. Chat displays an
unread badge; a message arriving on another tab shows an in-app reminder without
its private content. Background OS push notifications, media, games, recipes and
a durable offline outbox are future work. The input draft and failed sends are
retained across tab switches but not process restarts. Confirmed messages and
read cursors are persisted in SQLite.

The server now accesses SQLite through GORM models, rather than hand-written
CRUD SQL. `server/internal/pairing/models.go` maps the existing tables while
keeping API models independent of storage details. The official GORM SQLite
dialector uses the existing pure-Go `modernc.org/sqlite` connection. Reviewed
additive SQL migrations retain the original constraints and timestamp units;
startup deliberately avoids `AutoMigrate` on an existing private database.
Existing tokens, recovery codes, message IDs and read cursors remain compatible.
Credential rotation, one-time code redemption and message/read upserts keep
explicit transaction boundaries. SQL tracing is disabled for privacy.

The API contracts are `GET /api/v1/chat/messages`, `POST /api/v1/chat/messages`
and `POST /api/v1/chat/read`; see `server/README.md` for pagination, limits and
receipt semantics.

The following widget-rendered preview uses sample messages, not private data:

![Basic chat with paper bubbles, a read receipt and the Chat-first navigation](images/basic-chat.png)
Recovery codes are single-use and must be saved by each member outside the app.
Recovery revokes all of that member's sessions and outstanding device login codes,
then issues a new token and recovery code; the partner remains signed in. Use
device login codes for normal additional-device sign-in and recovery only when
access has been lost. Newly added devices do not receive recovery secrets.
Production deployments must mount and back up the configured SQLite database
path.
