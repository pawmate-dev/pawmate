# Next step: server pairing foundation

This is the first implementation task to take from the book into a feature
branch. It deliberately stops before Flutter UI work: the server must enforce
the relationship rules before the client can safely depend on them.

## Outcome

After this task, the Gin server can create and atomically redeem a single-use,
ten-minute pairing invitation for two authenticated users. The task is complete
only when concurrency and invalid-state tests pass.

## 1. Create the branch and establish a red test

```bash
git switch -c feat/couple-pairing-foundation
cd server
go test ./...
```

Start with a service-level test, not a Gin handler. The test should state the
desired result before a database or HTTP implementation exists:

```go
func TestRedeemInvitePairsTwoUnpairedUsers(t *testing.T) {
    store := newTestStore(t)
    creatorID := store.createUser(t, "Ari")
    recipientID := store.createUser(t, "Bo")
    service := NewPairingService(store, fixedClock)

    invite, err := service.CreateInvite(context.Background(), creatorID)
    if err != nil {
        t.Fatalf("CreateInvite() error = %v", err)
    }

    coupleID, err := service.RedeemInvite(context.Background(), recipientID, invite.Code)
    if err != nil {
        t.Fatalf("RedeemInvite() error = %v", err)
    }
    if coupleID == "" {
        t.Fatal("RedeemInvite() returned an empty couple ID")
    }
    store.assertSameCouple(t, creatorID, recipientID, coupleID)
}
```

The names and test helper APIs are examples. Preserve the behavior, not these
exact identifiers.

## 2. Add the smallest durable schema

Use a membership table so the database can guarantee one couple per user:

```sql
CREATE TABLE couples (
  id TEXT PRIMARY KEY,
  created_at TEXT NOT NULL
);

CREATE TABLE couple_members (
  couple_id TEXT NOT NULL REFERENCES couples(id),
  user_id TEXT NOT NULL UNIQUE REFERENCES users(id),
  PRIMARY KEY (couple_id, user_id)
);

CREATE TABLE pairing_invites (
  id TEXT PRIMARY KEY,
  creator_user_id TEXT NOT NULL REFERENCES users(id),
  code_hash BLOB NOT NULL UNIQUE,
  expires_at TEXT NOT NULL,
  redeemed_at TEXT,
  redeemed_by_user_id TEXT REFERENCES users(id)
);
```

Use the migration mechanism chosen for the server; do not run schema creation
inside a request handler. Keep a migration test that opens a fresh database and
confirms all expected tables and indexes exist.

## 3. Define domain errors and service methods

The HTTP layer should translate typed domain errors into status codes. It should
not contain pairing rules.

```go
var (
    ErrAlreadyPaired         = errors.New("user is already paired")
    ErrInvalidInvite         = errors.New("invite is invalid")
    ErrExpiredInvite         = errors.New("invite has expired")
    ErrCannotRedeemOwnInvite = errors.New("cannot redeem own invite")
)

type PairingService interface {
    CreateInvite(ctx context.Context, creatorUserID string) (Invite, error)
    RedeemInvite(ctx context.Context, recipientUserID, code string) (string, error)
}
```

An invitation code is a bearer secret. Generate 32 random bytes with
`crypto/rand`, encode them as Base64 URL text, return that text once, and save
only a SHA-256 hash of it. A short six-digit code is not an equivalent
replacement unless it has strong rate limiting and a much shorter lifetime.

## 4. Make redemption a transaction

Inside one database transaction, in this order:

1. Find an unredeemed invitation by its code hash.
2. Reject a missing or expired invitation.
3. Reject the invitation creator redeeming their own invite.
4. Confirm both users have no row in `couple_members`.
5. Insert one `couples` row and two `couple_members` rows.
6. Mark the invitation redeemed, checking that exactly one row changed.
7. Commit.

If any step fails, roll back everything. The service must never leave a couple
without two members or consume an invitation without creating a couple.

## 5. Write the failure tests before HTTP

| Test                                | Expected result                                |
| ----------------------------------- | ---------------------------------------------- |
| Creator redeems own invite          | `ErrCannotRedeemOwnInvite`                     |
| Invite is expired                   | `ErrExpiredInvite`                             |
| Invite was redeemed already         | `ErrInvalidInvite`                             |
| Recipient is already paired         | `ErrAlreadyPaired`                             |
| Two redemption requests race        | exactly one succeeds                           |
| Third registered user tries to join | rejected by the private-instance capacity rule |

Run these throughout the task:

```bash
gofmt -w .
go vet ./...
go test ./...
```

## 6. Only then expose the HTTP API

After the service tests pass, add authenticated handlers:

```text
POST /api/v1/pairing/invites
POST /api/v1/pairing/invites/redeem
GET  /api/v1/pairing/invites/status
```

The authentication middleware supplies the user ID. Do not accept `user_id` or
`couple_id` in either request body. Return a generic response for unknown,
expired, and already-consumed invitation codes so callers cannot learn which
codes were once valid.

## Review checkpoint

Before adding Flutter screens, confirm in review that passwords and session
tokens are handled independently from pairing: passwords are slow-hashed,
tokens are stored securely, and production traffic uses HTTPS.
