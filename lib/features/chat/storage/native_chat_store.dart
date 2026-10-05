import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../chat_api.dart';
import 'chat_store.dart';

/// Opens an encrypted, account-isolated database on a background isolate.
Future<ChatStore> openChatStore(ChatScope scope) async {
  final directory = await getApplicationSupportDirectory();
  final name = sha256.convert(utf8.encode(scope.key)).toString();
  final file = File('${directory.path}/chat-$name.sqlite');
  await directory.create(recursive: true);
  const secure = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  final keyName = 'pawmate.chat.key.$name';
  var key = await secure.read(key: keyName);
  if (key == null) {
    // Never replace a missing key for an existing database or delete that database.
    if (await file.exists()) {
      throw StateError('The chat database key is unavailable');
    }
    final random = Random.secure();
    key = List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await secure.write(key: keyName, value: key);
  }
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(key)) {
    throw StateError('Invalid chat database key');
  }
  return SqliteChatStore.encrypted(scope, file, key);
}

/// Explicit SQL schema through Drift's background executor; no generated code needed.
class _ChatDatabase extends GeneratedDatabase {
  _ChatDatabase(super.executor);
  @override
  int get schemaVersion => 2;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement('''CREATE TABLE messages (
      id INTEGER PRIMARY KEY, client_id TEXT NOT NULL, sender TEXT NOT NULL,
      text TEXT NOT NULL, created_at TEXT NOT NULL, confirmed INTEGER NOT NULL,
      UNIQUE(sender, client_id))''');
      await customStatement(
        'CREATE TABLE outbox (client_id TEXT PRIMARY KEY, text TEXT NOT NULL, created_at TEXT)',
      );
      await customStatement(
        'CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      );
    },
    onUpgrade: (_, from, to) async {
      if (from < 2) {
        await customStatement('ALTER TABLE outbox ADD COLUMN created_at TEXT');
      }
    },
  );
}

/// Stores pages and cursors atomically; imported messages cannot grant authority.
class SqliteChatStore extends ChatStore {
  SqliteChatStore(this.scope, QueryExecutor executor)
    : _db = _ChatDatabase(executor);

  /// Validates the actual encryption library in release builds, not just asserts.
  factory SqliteChatStore.encrypted(ChatScope scope, File file, String key) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(key)) {
      throw ArgumentError('Invalid encryption key');
    }
    return SqliteChatStore(
      scope,
      NativeDatabase.createInBackground(
        file,
        setup: (db) {
          if (db.select('PRAGMA cipher').isEmpty) {
            throw StateError('Encrypted SQLite is not available');
          }
          db.execute("PRAGMA key = '$key'");
          db.execute('PRAGMA journal_mode = WAL');
          db.execute('PRAGMA busy_timeout = 5000');
        },
      ),
    );
  }

  @override
  final ChatScope scope;
  final _ChatDatabase _db;

  /// Binds values rather than interpolating private message or profile content.
  Future<List<QueryRow>> _query(
    String sql, [
    List<Variable> values = const [],
  ]) => _db.customSelect(sql, variables: values).get();

  ChatMessage _message(QueryRow row) => ChatMessage(
    id: row.read<int>('id'),
    clientID: row.read<String>('client_id'),
    sender: row.read<String>('sender'),
    text: row.read<String>('text'),
    createdAt: DateTime.parse(row.read<String>('created_at')),
    serverConfirmed: row.read<int>('confirmed') == 1,
  );

  @override
  Future<List<ChatMessage>> messages({int? beforeID, int limit = 50}) async {
    if (limit < 1 || limit > 250) throw ArgumentError.value(limit);
    final rows = await _query(
      'SELECT * FROM messages ${beforeID == null ? '' : 'WHERE id < ?'} ORDER BY id DESC LIMIT ?',
      [if (beforeID != null) Variable<int>(beforeID), Variable<int>(limit)],
    );
    return rows.map(_message).toList().reversed.toList();
  }

  Future<String?> _metadata(String key) async {
    final rows = await _query('SELECT value FROM metadata WHERE key = ?', [
      Variable<String>(key),
    ]);
    return rows.isEmpty ? null : rows.single.read<String>('value');
  }

  Future<void> _putMetadata(String key, String value) => _db.customStatement(
    'INSERT INTO metadata(key,value) VALUES (?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',
    [key, value],
  );

  @override
  Future<ChatSyncState> syncState() async {
    final raw = await _metadata('sync');
    if (raw == null) return const ChatSyncState();
    final value = jsonDecode(raw) as Map<String, dynamic>;
    return ChatSyncState(
      afterID: value['after'] as int,
      latestID: value['latest'] as int,
      readID: value['read'] as int,
      partnerReadID: value['partner_read'] as int,
      unreadCount: value['unread'] as int,
      hasOlder: value['older'] as bool,
      historyBeforeID: value['history_before'] as int? ?? 0,
    );
  }

  Future<void> _upsert(ChatMessage row) async {
    if (row.serverConfirmed) {
      // A peer cannot reserve a forged server id for a genuine client message.
      await _db.customStatement(
        'DELETE FROM messages WHERE confirmed = 0 AND id != ? AND sender = ? AND client_id = ?',
        [row.id, row.sender, row.clientID],
      );
    }
    await _db.customStatement(
      '''INSERT INTO messages(id,client_id,sender,text,created_at,confirmed)
      VALUES (?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET client_id=excluded.client_id,
      sender=excluded.sender,text=excluded.text,created_at=excluded.created_at,confirmed=excluded.confirmed''',
      [
        row.id,
        row.clientID,
        row.sender,
        row.text,
        row.createdAt.toUtc().toIso8601String(),
        row.serverConfirmed ? 1 : 0,
      ],
    );
    if (row.serverConfirmed && row.sender == scope.role) {
      await removeOutgoing(row.clientID);
    }
  }

  @override
  Future<void> commit(List<ChatMessage> messages, {ChatSyncState? state}) =>
      _db.transaction(() async {
        for (final row in messages) {
          await _upsert(row);
        }
        if (state != null) {
          await _putMetadata(
            'sync',
            jsonEncode({
              'after': state.afterID,
              'latest': state.latestID,
              'read': state.readID,
              'partner_read': state.partnerReadID,
              'unread': state.unreadCount,
              'older': state.hasOlder,
              'history_before': state.historyBeforeID,
            }),
          );
        }
      });

  @override
  Future<List<StoredOutgoing>> outbox() async =>
      (await _query('SELECT * FROM outbox ORDER BY rowid'))
          .map(
            (row) => StoredOutgoing(
              row.read<String>('client_id'),
              row.read<String>('text'),
              createdAt: DateTime.tryParse(
                row.readNullable<String>('created_at') ?? '',
              ),
            ),
          )
          .toList();
  @override
  Future<void> putOutgoing(StoredOutgoing row) => _db.customStatement(
    'INSERT INTO outbox(client_id,text,created_at) VALUES (?,?,?) ON CONFLICT(client_id) DO NOTHING',
    [row.clientID, row.text, row.createdAt?.toUtc().toIso8601String()],
  );
  @override
  Future<void> removeOutgoing(String clientID) =>
      _db.customStatement('DELETE FROM outbox WHERE client_id = ?', [clientID]);
  @override
  Future<String> draft() async => await _metadata('draft') ?? '';
  @override
  Future<void> saveDraft(String text) => _putMetadata('draft', text);
  @override
  Future<Map<String, dynamic>?> profile() async {
    final raw = await _metadata('profile');
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<void> saveProfile(Map<String, dynamic> profile) =>
      _putMetadata('profile', jsonEncode(profile));
  @override
  Future<void> close() => _db.close();

  @override
  Future<ChatHistoryBatch> exportHistory({
    int afterID = 0,
    int limit = 250,
  }) async {
    if (limit < 1 || limit > ChatHistoryBatch.maxMessages) {
      throw ArgumentError.value(limit);
    }
    final rows = await _query(
      'SELECT * FROM messages WHERE id > ? ORDER BY id LIMIT ?',
      [Variable<int>(afterID), Variable<int>(limit)],
    );
    return ChatHistoryBatch(
      serverURL: scope.serverURL,
      pairID: scope.pairID,
      messages: rows.map(_message).toList(),
    );
  }

  @override
  Future<int> importHistory(ChatHistoryBatch batch) async {
    validateBatch(batch);
    return _db.transaction(() async {
      var inserted = 0;
      for (final row in batch.messages) {
        final existing = await _query(
          'SELECT * FROM messages WHERE id = ? OR (sender = ? AND client_id = ?)',
          [
            Variable<int>(row.id),
            Variable<String>(row.sender),
            Variable<String>(row.clientID),
          ],
        );
        if (existing.isNotEmpty) {
          if (existing.length != 1 ||
              jsonEncode(_message(existing.single).toJson()) !=
                  jsonEncode(row.toJson())) {
            throw const FormatException('Conflicting history message');
          }
          continue;
        }
        await _upsert(
          ChatMessage(
            id: row.id,
            clientID: row.clientID,
            sender: row.sender,
            text: row.text,
            createdAt: row.createdAt,
            serverConfirmed: false,
          ),
        );
        inserted++;
      }
      // Never change server sync, read receipts or outbox during peer imports.
      return inserted;
    });
  }
}
