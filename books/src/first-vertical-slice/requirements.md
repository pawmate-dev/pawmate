# Requirements and decisions

## Product rules

- A Pawmate instance is private and supports exactly one couple: at most two
  users may be active in a couple.
- A user must select a server before signing in or pairing.
- A pairing invitation is single-use and short-lived.
- Once paired, both client and server scope shared data by the couple ID.
- The server URL and login session must survive an app restart.

## Decisions to approve before implementation

| Decision | Recommended starting point | Why it needs approval |
| --- | --- | --- |
| Database | SQLite | It is simple to self-host and sufficient for one couple. |
| Authentication | Password plus short-lived access token and refresh token | It avoids treating the private network as authentication. |
| Transport | HTTPS in production | Messages, backups, and tokens are private data. |
| Local development URL | `http://10.0.2.2:8080` on the Android emulator | This reaches the host machine from the emulator. |
| Pairing mechanism | QR code containing a one-time opaque code, with text fallback | It is simple to share in person and does not expose a reusable secret. |

Do not accept a certificate error silently. For local HTTP development, permit
cleartext traffic only in the Android debug configuration; production builds
must use HTTPS.

## Initial data model

```text
users
  id, display_name, password_hash, created_at

couples
  id, first_user_id, second_user_id, created_at

pairing_invites
  id, creator_user_id, code_hash, expires_at, redeemed_at

refresh_tokens
  id, user_id, token_hash, expires_at, revoked_at
```

Store password hashes and invitation/token hashes, never the original secret.
