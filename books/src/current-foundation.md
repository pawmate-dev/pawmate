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
session-validation endpoint.

The current implementation is an onboarding foundation. It does not yet
provide chat, media, games, recipes, or a feature-rich paired-home dashboard.
Recovery codes are single-use and must be saved by each member outside the app.
Production deployments must mount and back up the configured SQLite database
path.
