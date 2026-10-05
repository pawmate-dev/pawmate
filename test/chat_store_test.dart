import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pawmate/features/chat/chat_api.dart';
import 'package:pawmate/features/chat/chat_controller.dart';
import 'package:pawmate/features/chat/storage/chat_store.dart';
import 'package:pawmate/features/chat/storage/native_chat_store.dart';
import 'package:pawmate/features/pairing/pairing_credentials.dart';

const credentials = SavedPairingCredentials(
  serverURL: 'https://home.example.test',
  accessToken: 'secret-token',
  recoveryCode: 'secret-recovery',
  pairID: 'pair',
  role: 'inviter',
);

ChatScope scope({String role = 'inviter'}) => ChatScope(
  serverURL: credentials.serverURL,
  pairID: credentials.pairID,
  role: role,
);

ChatMessage message(
  int id, {
  String text = 'Private text',
  String sender = 'invitee',
}) => ChatMessage(
  id: id,
  clientID: 'client-$id',
  sender: sender,
  text: text,
  createdAt: DateTime.utc(2026, 10, 6),
);

http.Response snapshot(
  List<ChatMessage> rows, {
  int latest = 0,
  bool more = false,
}) => http.Response(
  jsonEncode({
    'messages': rows.map((row) => row.toJson()).toList(),
    'has_more': more,
    'latest_id': latest,
    'read_id': 0,
    'partner_read_id': 0,
    'unread_count': 0,
  }),
  200,
);

void main() {
  for (final useSqlite in [false, true]) {
    final name = useSqlite ? 'SQLite' : 'Memory';
    group(name, () {
      late ChatStore store;
      setUp(
        () => store = useSqlite
            ? SqliteChatStore(scope(), NativeDatabase.memory())
            : MemoryChatStore(scope()),
      );
      tearDown(() => store.close());

      test(
        '$name bounds local pagination and keeps send acknowledgments out of cursor',
        () async {
          await store.commit(
            List.generate(100, (index) => message(index + 1)),
            state: const ChatSyncState(afterID: 100, latestID: 100),
          );
          expect(
            (await store.messages()).map((row) => row.id),
            List.generate(50, (index) => index + 51),
          );
          expect((await store.messages(beforeID: 51)).first.id, 1);
          await store.putOutgoing(
            const StoredOutgoing('client-101', 'Queued text'),
          );
          await store.commit([message(101, sender: 'inviter')]);
          expect((await store.syncState()).afterID, 100);
          expect(await store.outbox(), isEmpty);
          await store.saveDraft('Draft');
          await store.saveProfile({'role': 'inviter'});
          expect(await store.draft(), 'Draft');
          expect(await store.profile(), {'role': 'inviter'});
        },
      );

      test(
        '$name export is paginated and contains no authority or credentials',
        () async {
          await store.commit([
            message(1),
            message(2),
          ], state: const ChatSyncState(afterID: 2, readID: 1));
          await store.putOutgoing(const StoredOutgoing('pending', 'Not sent'));
          final batch = await store.exportHistory(limit: 1);
          final value = batch.toJson();
          expect(value.keys.toSet(), {
            'version',
            'server_url',
            'pair_id',
            'messages',
          });
          expect(batch.messages.single.id, 1);
          expect((await store.exportHistory(afterID: 1)).messages.single.id, 2);
          expect(
            ChatHistoryBatch.fromJson(value).messages.single.text,
            'Private text',
          );
          expect(jsonEncode(value), isNot(contains('secret-token')));
          expect(jsonEncode(value), isNot(contains('Not sent')));
        },
      );

      test(
        '$name peer imports deduplicate but never advance cursors or receipts',
        () async {
          await store.commit([
            message(1),
          ], state: const ChatSyncState(afterID: 1, readID: 1));
          final batch = ChatHistoryBatch(
            serverURL: credentials.serverURL,
            pairID: 'pair',
            messages: [message(2)],
          );
          expect(await store.importHistory(batch), 1);
          expect(await store.importHistory(batch), 0);
          final state = await store.syncState();
          expect(state.afterID, 1);
          expect(state.readID, 1);
          expect((await store.messages()).last.serverConfirmed, isFalse);
          await store.commit([
            message(2),
          ], state: const ChatSyncState(afterID: 2));
          expect((await store.messages()).last.serverConfirmed, isTrue);
        },
      );

      test('$name rejects conflicting or foreign batches atomically', () async {
        await store.commit([message(1)]);
        await expectLater(
          store.importHistory(
            ChatHistoryBatch(
              serverURL: credentials.serverURL,
              pairID: 'another-pair',
              messages: [message(2)],
            ),
          ),
          throwsFormatException,
        );
        await expectLater(
          store.importHistory(
            ChatHistoryBatch(
              serverURL: credentials.serverURL,
              pairID: 'pair',
              messages: [
                message(2),
                message(1, text: 'Tampered'),
              ],
            ),
          ),
          throwsFormatException,
        );
        expect((await store.messages()).map((row) => row.id), [1]);
        await expectLater(
          store.importHistory(
            ChatHistoryBatch(
              serverURL: credentials.serverURL,
              pairID: 'pair',
              version: 2,
              messages: [],
            ),
          ),
          throwsFormatException,
        );
      });

      test(
        '$name peer echoes cannot clear a pending send or reserve its id',
        () async {
          await store.putOutgoing(
            const StoredOutgoing('client-2', 'Private text'),
          );
          await store.importHistory(
            ChatHistoryBatch(
              serverURL: credentials.serverURL,
              pairID: 'pair',
              messages: [
                ChatMessage(
                  id: 999,
                  clientID: 'client-2',
                  sender: 'inviter',
                  text: 'Private text',
                  createdAt: DateTime.utc(2026, 10, 6),
                ),
              ],
            ),
          );
          expect((await store.outbox()).single.clientID, 'client-2');
          expect((await store.syncState()).afterID, 0);
          await store.commit([message(2, sender: 'inviter')]);
          expect((await store.messages()).map((row) => row.id), [2]);
          expect(await store.outbox(), isEmpty);
        },
      );
    });
  }

  test(
    'encrypted background database survives restart and rejects a wrong key',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'pawmate-cache-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/chat.sqlite');
      final key = List.filled(64, 'a').join();
      final first = SqliteChatStore.encrypted(scope(), file, key);
      await first.commit([
        message(7, text: 'confidential-chat-text'),
      ], state: const ChatSyncState(afterID: 7));
      await first.putOutgoing(
        const StoredOutgoing('pending-id', 'queued-private-text'),
      );
      await first.saveDraft('private-draft');
      await first.close();
      final raw = await file.readAsBytes();
      expect(
        utf8.decode(raw, allowMalformed: true),
        isNot(contains('confidential-chat-text')),
      );
      expect(
        utf8.decode(raw.take(16).toList(), allowMalformed: true),
        isNot(startsWith('SQLite format')),
      );
      final second = SqliteChatStore.encrypted(scope(), file, key);
      expect((await second.messages()).single.id, 7);
      expect((await second.syncState()).afterID, 7);
      expect((await second.outbox()).single.clientID, 'pending-id');
      expect(await second.draft(), 'private-draft');
      await second.close();
      final wrong = SqliteChatStore.encrypted(
        scope(),
        file,
        List.filled(64, 'b').join(),
      );
      await expectLater(wrong.messages(), throwsA(anything));
      await wrong.close();
      expect(await file.exists(), isTrue);
    },
  );

  test(
    'cache is visible before a delayed server request and resumes from durable cursor',
    () async {
      final store = MemoryChatStore(scope());
      await store.commit([
        message(5),
      ], state: const ChatSyncState(afterID: 5, latestID: 5));
      int? after;
      final chat = ChatController(
        ChatApi(
          credentials,
          MockClient((request) async {
            after = int.parse(request.url.queryParameters['after_id']!);
            return snapshot([message(6)], latest: 6);
          }),
        ),
        store: Future.value(store),
        requireVerification: true,
      );
      await chat.initialize();
      expect(chat.messages.single.id, 5);
      expect(after, isNull);
      expect(chat.loading, isFalse);
      chat.allowNetwork(true);
      await chat.synchronize();
      expect(after, 5);
      expect(chat.messages.map((row) => row.id), [5, 6]);
      chat.dispose();
    },
  );

  test(
    'local older pages and offline outbox require no network requests',
    () async {
      final store = MemoryChatStore(scope());
      await store.commit(
        List.generate(100, (index) => message(index + 1)),
        state: const ChatSyncState(afterID: 100, latestID: 100),
      );
      var requests = 0;
      final chat = ChatController(
        ChatApi(
          credentials,
          MockClient((_) async {
            requests++;
            return snapshot([]);
          }),
        ),
        store: Future.value(store),
        requireVerification: true,
      );
      await chat.initialize();
      await chat.loadOlder();
      expect(chat.messages.length, 100);
      await chat.send('Offline queued message');
      expect(requests, 0);
      expect(
        (await store.outbox()).single.clientID,
        chat.outbox.single.clientID,
      );
      expect(chat.outbox.single.sending, isFalse);
      chat.dispose();
    },
  );

  test('restored outbox retries its original id after verification', () async {
    final store = MemoryChatStore(scope());
    await store.putOutgoing(const StoredOutgoing('client-9', 'Private text'));
    await store.saveDraft('Draft retained on restart');
    String? sentID;
    var delivered = false;
    final chat = ChatController(
      ChatApi(
        credentials,
        MockClient((request) async {
          if (request.method == 'POST') {
            sentID =
                (jsonDecode(request.body) as Map<String, dynamic>)['client_id']
                    as String;
            delivered = true;
            return http.Response(
              jsonEncode(message(9, sender: 'inviter').toJson()),
              200,
            );
          }
          return snapshot(
            delivered ? [message(9, sender: 'inviter')] : [],
            latest: delivered ? 9 : 0,
          );
        }),
      ),
      store: Future.value(store),
      requireVerification: true,
    );
    await chat.initialize();
    expect(chat.savedDraft, 'Draft retained on restart');
    expect(chat.outbox.single.sending, isFalse);
    expect(sentID, isNull);
    chat.allowNetwork(true);
    await chat.synchronize();
    expect(sentID, 'client-9');
    expect(await store.outbox(), isEmpty);
    expect(chat.messages.single.id, 9);
    chat.dispose();
  });
}
