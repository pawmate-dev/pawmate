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
rotates the access token and recovery code, so the old recovery code can no
longer be used. A recovery code belongs to one member; the two members should
keep separate codes.

For the Android emulator, configure the Flutter client with
`http://10.0.2.2:8080`; `10.0.2.2` maps to the development machine's loopback
interface from inside the emulator.

## Configuration

Copy `.env.example` into your process environment before starting the server.
The environment variables control the port, database path, and stable identity
shown to clients. Production instances should set a real HTTPS
`PAWMATE_PUBLIC_URL` and keep the SQLite database on a persistent volume.

## Verify

```bash
go test ./...
```
