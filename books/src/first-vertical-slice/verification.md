# Verification and review

## Server checks

```bash
cd server
gofmt -w .
go vet ./...
go test ./...
```

Add tests for at least these cases:

- a compatible and incompatible instance response;
- registration up to the two-user limit;
- password verification failure;
- expired, reused, self-redeemed, and valid invitations;
- two concurrent redemption attempts for one invitation;
- an already-paired user attempting to pair again.

## Flutter checks

```bash
dart format .
flutter analyze
flutter test
```

Manually verify on an Android emulator:

1. Start the server and enter `http://10.0.2.2:8080`.
2. Confirm an unreachable or invalid URL has a useful recovery path.
3. Register two accounts and pair them with one invitation.
4. Restart the app and confirm the server selection and session behavior are
   correct.
5. Confirm a third account cannot join the private instance.

For the current inviter MVP, manually verify invitation creation with:

```bash
curl -X POST http://localhost:8080/api/v1/pairing/invites \
  -H 'content-type: application/json' \
  -d '{"server_url":"http://localhost:8080"}'
```

Save the returned `invite_url` and `inviter_token` only in a local shell. The
invite URL is a bearer secret; do not paste it into commits, logs, or issues.

## Pull request review

Before merging, verify that:

- server and Flutter API contracts agree;
- no production cleartext traffic was enabled;
- no secrets or private test data appear in the diff;
- migration and rollback behavior is understood;
- the two-user invariant is enforced by the server, not only by the UI.
