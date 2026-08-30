# Pawmate server

Gin HTTP API for a private Pawmate instance. The initial endpoints allow the
Flutter client to verify a configured instance URL before registration and
couple pairing are added.

## Run locally

```bash
go run ./cmd/pawmate-server
```

The server listens on `http://localhost:8080` by default.

```bash
curl http://localhost:8080/healthz
curl http://localhost:8080/api/v1/instance
```

The inviter pairing MVP exposes:

```text
POST /api/v1/pairing/invites
GET  /api/v1/pairing/invites/status
POST /api/v1/pairing/invites/redeem
```

Create an invitation by sending the configured server URL:

```bash
curl -X POST http://localhost:8080/api/v1/pairing/invites \
  -H 'content-type: application/json' \
  -d '{"server_url":"http://localhost:8080"}'
```

The response contains a one-time `invite_url` and an `inviter_token` for status
checks. This initial implementation stores pairing state in memory for local
development; restarting the process clears it. Add persistent storage before
deploying a real instance.

For the Android emulator, configure the Flutter client with
`http://10.0.2.2:8080`; `10.0.2.2` maps to the development machine's loopback
interface from inside the emulator.

## Configuration

Copy `.env.example` into your process environment before starting the server.
The environment variables control the port and the stable identity shown to
clients. Production instances should set a real HTTPS `PAWMATE_PUBLIC_URL`.

## Verify

```bash
go test ./...
```
