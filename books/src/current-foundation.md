# Current foundation

The repository currently contains two independent applications:

| Area           | Location        | Current responsibility             |
| -------------- | --------------- | ---------------------------------- |
| Flutter client | repository root | Android-ready Pawmate client shell |
| Gin server     | `server/`       | Private-instance discovery API     |

The Gin server already exposes these unauthenticated discovery endpoints:

```text
GET /healthz
GET /api/v1/instance
```

`GET /api/v1/instance` is the first contract between the client and a private
Pawmate instance. It reports an instance identifier, display name, API version,
public URL when configured, and the currently advertised features.

The next slice extends this foundation with a safe onboarding and pairing flow.
It must not weaken the existing discovery endpoint or make private data public.
