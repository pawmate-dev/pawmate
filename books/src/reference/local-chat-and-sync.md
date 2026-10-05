# Local chat history and synchronization

## Local-first startup

After reading saved credentials, `PairingSessionGate` opens the couple space
without waiting for a server response. `ChatController.initialize()` reads the
latest 50 cached messages, the draft, pending outgoing messages, receipts and
cached member profiles. Older cached pages are read on demand.

`PairedHomePage` validates the saved credential in the background. Cached access
is not remote authorization: protected chat requests remain disabled until the
server confirms the same paired member and pair ID. Network failure appears
below the toolbar and leaves local history accessible. Revoked access disables
sending without deleting the cache or automatically navigating away.

Open the overlapping portraits, then **Settings**, to change language, recheck
the connection, restore access or choose another sign-in method. Recovery can
revoke the member's other devices; it is an explicit user action.

## Native encrypted storage

`lib/features/chat/storage/` separates the storage contract from its adapter.
The native adapter uses Drift with explicit SQL tables, an encrypted SQLite
implementation (`sqlite3mc`) and a background database executor. It persists:

- confirmed messages and imported history
- server synchronization/read metadata
- the idempotent outgoing queue
- the compose draft and cached member profiles

Each database is scoped to normalized server URL, pair ID and member role.
Its random encryption key is stored separately in platform secure storage;
bearer tokens and recovery codes never enter history exchange pages. A missing
key for an existing database is an error, not permission to replace the database.
Storage failure leaves the existing files intact, shows a warning and temporarily
uses memory. Native database encryption does not encrypt a future exported file
or transport channel automatically.

The browser adapter currently has no durable cache: it uses the explicit
memory fallback and displays the storage warning. Native platforms must still
have their platform-specific secure-storage prerequisites configured.

## Server synchronization and offline sends

Server-delivered pages and their forward cursor are committed atomically.
Restart resumes with `after_id`; it does not download the same initial history
on every launch. Initial synchronization only fetches the newest server page,
not a complete backup. Older history is fetched when requested, after available
local pages, using a separate server `historyBeforeID` cursor.

Sending first persists an outbox item with a random `client_id`. Network retry
and restart keep that ID so the server can deduplicate ambiguous deliveries.
A send acknowledgment does not advance the fetch cursor: messages arriving
between the previous poll and the send response must still be fetched.

Only server-confirmed messages rendered in the visible foreground chat may
advance read receipts, after forward synchronization catches up. Imported
history cannot claim synchronization progress, clear an outgoing item, or
mark a message read.

## Extension point for device-to-device history

Server backups remain possible independently of the local cache. Future file,
LAN or other authenticated device transports can use `ChatHistoryExchange`:

```dart
abstract interface class ChatHistoryExchange {
  Future<ChatHistoryBatch> exportHistory({int afterID = 0, int limit = 250});
  Future<int> importHistory(ChatHistoryBatch batch);
}
```

`ChatController` exposes the same methods. A version-1 batch contains only
`version`, `server_url`, `pair_id` and `messages`. Page through ascending IDs
using the last exported message ID; each batch is limited to 250 messages.
Exports are content snapshots, not a synchronized multi-page backup session.

Import validates the protocol version, matching server/pair, message limits,
roles and IDs. It deduplicates exact records and atomically rejects conflicting
IDs or sender/client-ID identities rather than silently overwriting history.
Imported rows are locally unconfirmed until the server confirms them; importing
never changes server cursors, receipts or the outbox. Canonical server messages
can correct an unconfirmed imported identity.

These methods are extension points, not a shipped transfer feature. Before
connecting them to a transport, add authenticated peer/device authorization,
encrypted transfer, payload byte limits before decoding, integrity checks,
resumable manifests, cancellation and user consent. A matching URL/pair ID is
not proof that a peer is authorized. Neither encryption keys nor authentication
credentials should be transferred through this content-only protocol.

## Verification

`test/chat_store_test.dart` exercises pagination, encryption and reopening,
cursor/outbox separation, drafts, import deduplication and atomic conflict
rejection. `test/offline_startup_test.dart` checks that cached chat opens while
the server response is pending, offline errors sit below the toolbar, Settings
changes language, and revoked credentials preserve readable local history.
