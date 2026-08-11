# User journey and API contract

## User journey

```text
Launch app
  -> enter server URL
  -> GET /api/v1/instance
  -> compatible instance?
     -> no: explain the problem and allow URL editing
     -> yes: register or sign in
  -> paired already?
     -> yes: open shared home
     -> no: create or redeem an invitation
  -> open shared home
```

## Preserve the discovery endpoint

The existing endpoint remains public:

```http
GET /api/v1/instance
```

It should return only non-sensitive metadata. The Flutter client must reject an
unknown API version before attempting authentication.

## New API surface

Use `/api/v1` consistently. Exact request and response field names should be
documented in tests before the Flutter UI depends on them.

```text
POST /api/v1/auth/register
POST /api/v1/auth/login
POST /api/v1/auth/refresh
POST /api/v1/auth/logout

GET  /api/v1/me
GET  /api/v1/couple
POST /api/v1/pairing-invites
POST /api/v1/pairing-invites/redeem
```

Suggested behavior:

| Endpoint                       | Authentication | Success behavior                                              |
| ------------------------------ | -------------- | ------------------------------------------------------------- |
| `POST /auth/register`          | No             | Creates a user only while the instance has capacity.          |
| `POST /auth/login`             | No             | Returns an access token and refresh token.                    |
| `GET /me`                      | Yes            | Returns the current user and pairing state.                   |
| `GET /couple`                  | Yes            | Returns the couple or a not-paired state.                     |
| `POST /pairing-invites`        | Yes            | Creates one expiring, single-use invite for an unpaired user. |
| `POST /pairing-invites/redeem` | Yes            | Atomically creates the couple and consumes the invite.        |

Return generic authentication errors. Do not reveal whether a display name,
email address, invite code, or server contains a particular user.
