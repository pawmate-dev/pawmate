# Client journeys and service contracts

## Client journeys

On a new installation, the access screen offers invitation creation,
invitation acceptance, account recovery, and additional-device sign-in. Each
choice opens a focused flow. Existing pending invitations resume their status
view, valid paired sessions open the couple space, and revoked or invalid
sessions lead to recovery. Network failures remain retryable and do not erase
saved credentials.

Invitation links use the `pawmate://pair` scheme. The client parses pasted and
externally opened links through the same validation path. It displays the server
address for review before redeeming the invitation. Clipboard access occurs only
when the user selects the paste action.

The paired space opens on Chat and also contains Play and Home. Home presents
member profiles, recovery guidance, and device management. Play is currently a
placeholder.

## Discovery and pairing API

`GET /healthz` reports server health. `GET /api/v1/instance` returns public
instance metadata: identifier, display name, API version, optional public URL,
and advertised features. It does not return member or couple data.

The pairing API creates and redeems invitations, checks invitation status,
restores access with recovery codes, and validates sessions:

```text
POST /api/v1/pairing/invites
GET  /api/v1/pairing/invites/status
POST /api/v1/pairing/invites/redeem
POST /api/v1/pairing/recover
GET  /api/v1/pairing/session
```

Invitation creation and acceptance include a member profile. Invitation codes
expire after ten minutes and can be redeemed once. The authenticated session
response includes the current member's role and profile and, when paired, the
partner profile. See `server/README.md` for request fields and limits.

## Device API

Device login codes are issued by an authenticated member and redeemed without an
existing access token on the new installation:

```text
GET    /api/v1/pairing/devices
DELETE /api/v1/pairing/devices/:id
POST   /api/v1/pairing/devices/login-codes
POST   /api/v1/pairing/devices/login-codes/redeem
```

Device listings are scoped to the authenticated member. A device login code
expires after ten minutes, can be redeemed once, and returns a new device token
without disclosing a recovery code.

## Chat API

All chat endpoints require an active paired-device token. The server derives
member and pair identity from the token:

```text
GET  /api/v1/chat/messages
POST /api/v1/chat/messages
POST /api/v1/chat/read
```

Messages have a server sequence ID and a client-generated idempotency ID.
History supports pagination in either direction. Read cursors belong to members
and only move forward, so reading on one device updates receipts across all of a
member's devices. The client acknowledges incoming messages only when they are
rendered in the foreground chat viewport.

The client polls every two seconds while foregrounded. It pauses in the
background and catches up on resume. Unread alerts contain no message content.
See `server/README.md` for pagination fields, limits, and receipt semantics.
