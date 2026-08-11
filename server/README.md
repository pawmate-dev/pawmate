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
