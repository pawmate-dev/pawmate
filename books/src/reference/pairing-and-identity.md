# Pairing and member identity

## Instance and couple model

A Pawmate server represents one private instance and one couple. The paired
members share a pair identifier, while each member has an independent role,
profile, recovery code, and set of device sessions. The server enforces these
relationships; client navigation does not grant access by itself.

An invitation is a short-lived, single-use bearer credential. Its code is
returned to the inviter for sharing, while the server stores only its hash.
Accepting an invitation associates the invitee with the inviter in a single
transaction. Rejected profile data does not consume the invitation.

## Member profiles

Each member profile contains a nickname and an optional avatar. Nicknames are
trimmed, limited to 1–32 Unicode characters, and cannot contain control
characters. Avatars arrive as PNG or JPEG data, are limited in size and
dimensions, and are re-encoded by the server as PNG to remove embedded metadata.
Profiles are saved in the same transaction as invitation creation or
acceptance. Existing pairs without profiles remain valid.

## Recovery and devices

Each member receives a single-use recovery code when pairing succeeds. Recovery
rotates that member's credentials, revokes their active sessions and outstanding
device login codes, and leaves the partner's sessions active. Recovery codes are
not delivered to additional devices.

An authenticated device can issue a one-time login code for another installation.
The code expires after ten minutes and creates an independent device session.
Members can list and revoke their own device sessions; they cannot inspect or
revoke the partner's devices. Revoked credentials are rejected by subsequent
authenticated requests.

## Persistence and privacy

SQLite stores the pair, profiles, hashed credentials, device sessions, messages,
and read cursors. The database is private instance data and needs persistent
storage and protected backups. Credential values are stored as hashes. Message
content is stored as readable text in SQLite, so Pawmate chat is not end-to-end
encrypted.
