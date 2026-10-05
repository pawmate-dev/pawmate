import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pawmate/design/theme/pawmate_theme.dart';
import 'package:pawmate/features/chat/chat_api.dart';
import 'package:pawmate/features/chat/chat_controller.dart';
import 'package:pawmate/features/chat/chat_page.dart';
import 'package:pawmate/features/pairing/pairing_credentials.dart';
import 'package:pawmate/features/pairing/paired_home_page.dart';
import 'package:pawmate/design/components/couple_header_avatars.dart';
import 'package:pawmate/features/pairing/pairing_api.dart';
import 'package:pawmate/features/pairing/couple_details_page.dart';
import 'package:pawmate/features/pairing/widgets/devices_card.dart';
import 'package:pawmate/features/pairing/widgets/recovery_code_note.dart';
import 'package:pawmate/features/chat/storage/chat_store.dart';
import 'package:pawmate/l10n/generated/app_localizations.dart';

const credentials = SavedPairingCredentials(
  serverURL: 'https://home.example.test',
  accessToken: 'phone-token',
  recoveryCode: '',
  pairID: 'our-home',
  role: 'inviter',
);

Map<String, dynamic> message(
  int id,
  String sender, {
  String clientID = 'client-id',
  String text = '你好 🐾',
}) => {
  'id': id,
  'client_id': clientID,
  'sender': sender,
  'text': text,
  'created_at': '2026-10-04T10:00:00Z',
};

http.Response snapshot(
  List<Map<String, dynamic>> messages, {
  int read = 0,
  int partnerRead = 0,
  int unread = 0,
  int latest = 0,
}) => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'messages': messages,
      'has_more': false,
      'latest_id': latest,
      'read_id': read,
      'partner_read_id': partnerRead,
      'unread_count': unread,
    }),
  ),
  200,
);

void main() {
  test(
    'a lost send response retries with the same id and no duplicate bubble',
    () async {
      var attempts = 0;
      final ids = <String>[];
      final chat = ChatController(
        ChatApi(
          credentials,
          MockClient((request) async {
            expect(request.headers['authorization'], 'Bearer phone-token');
            if (request.method == 'GET') return snapshot([]);
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            ids.add(body['client_id'] as String);
            if (attempts++ == 0) throw http.ClientException('response lost');
            return http.Response.bytes(
              utf8.encode(
                jsonEncode(message(1, 'inviter', clientID: ids.last)),
              ),
              200,
            );
          }),
        ),
      );
      addTearDown(chat.dispose);
      await chat.synchronize();
      await chat.send('你好 🐾');
      expect(chat.outbox.single.sending, isFalse);
      await chat.retry(chat.outbox.single);
      await Future<void>.delayed(Duration.zero);
      expect(ids[0], ids[1]);
      expect(chat.outbox, isEmpty);
      expect(chat.messages.single.text, '你好 🐾');
    },
  );

  test(
    'a send response ahead of polling does not skip an intervening partner message',
    () async {
      final catchup = Completer<http.Response>();
      final afterIDs = <String?>[];
      final chat = ChatController(
        ChatApi(
          credentials,
          MockClient((request) async {
            if (request.method == 'POST') {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              return http.Response.bytes(
                utf8.encode(
                  jsonEncode(
                    message(
                      3,
                      'inviter',
                      clientID: body['client_id'] as String,
                    ),
                  ),
                ),
                200,
              );
            }
            afterIDs.add(request.url.queryParameters['after_id']);
            if (afterIDs.length == 1) {
              return snapshot([message(1, 'inviter')], latest: 1);
            }
            return catchup.future;
          }),
        ),
      );
      addTearDown(chat.dispose);
      await chat.synchronize();
      await chat.send('another message');
      await Future<void>.delayed(Duration.zero);
      expect(chat.caughtUp, isFalse);
      expect(afterIDs.last, '1');
      catchup.complete(
        snapshot(
          [message(2, 'invitee'), message(3, 'inviter')],
          latest: 3,
          unread: 1,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(chat.messages.map((item) => item.id), [1, 2, 3]);
      expect(chat.unreadCount, 1);
      expect(chat.caughtUp, isTrue);
    },
  );

  test(
    'hidden chat and background application never advance read progress',
    () async {
      var read = 0;
      var readRequests = 0;
      final chat = ChatController(
        ChatApi(
          credentials,
          MockClient((request) async {
            if (request.method == 'POST') {
              readRequests++;
              read =
                  (jsonDecode(request.body)
                          as Map<String, dynamic>)['message_id']
                      as int;
              return http.Response(jsonEncode({'read_id': read}), 200);
            }
            return snapshot(
              [message(7, 'invitee'), message(10, 'invitee')],
              latest: 10,
              read: read,
              unread: read == 0 ? 2 : 1,
            );
          }),
        ),
      );
      addTearDown(chat.dispose);
      await chat.synchronize();
      chat.setChatVisible(false);
      await chat.markVisibleRead(10);
      chat.setChatVisible(true);
      chat.setForeground(false);
      await chat.markVisibleRead(10);
      expect(readRequests, 0);
      chat.setForeground(true);
      await Future<void>.delayed(Duration.zero);
      await chat.markVisibleRead(7);
      await Future<void>.delayed(Duration.zero);
      expect(read, 7);
      expect(chat.unreadCount, 1);
      await chat.markVisibleRead(5);
      expect(readRequests, 1);
    },
  );

  testWidgets(
    'only a visible foreground chat acknowledges rendered incoming messages',
    (tester) async {
      var read = 0;
      final chat = ChatController(
        ChatApi(
          credentials,
          MockClient((request) async {
            if (request.method == 'POST') {
              read =
                  (jsonDecode(request.body)
                          as Map<String, dynamic>)['message_id']
                      as int;
              return http.Response(jsonEncode({'read_id': read}), 200);
            }
            return snapshot(
              [message(1, 'invitee'), message(2, 'inviter')],
              latest: 2,
              read: read,
              partnerRead: 2,
              unread: read == 0 ? 1 : 0,
            );
          }),
        ),
      );
      addTearDown(chat.dispose);
      await chat.synchronize();
      Widget page(bool active) => MaterialApp(
        theme: buildPawmateTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChatPage(controller: chat, active: active),
        ),
      );
      await tester.pumpWidget(page(false));
      await tester.pumpAndSettle();
      expect(read, 0);
      expect(find.textContaining('Read'), findsOneWidget);
      await tester.pumpWidget(page(true));
      await tester.pumpAndSettle();
      expect(read, 1);
      expect(chat.unreadCount, 0);
    },
  );

  testWidgets('chat composer fits large accessibility text on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final chat = ChatController(
      ChatApi(credentials, MockClient((_) async => snapshot([]))),
    );
    addTearDown(chat.dispose);
    await chat.synchronize();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPawmateTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(body: ChatPage(controller: chat, active: true)),
      ),
    );
    await tester.enterText(find.byType(TextField), 'hello\nfrom a tablet');
    await tester.pump();
    expect(find.byTooltip('Send message'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('couple space opens on Chat and alerts without reading on Life', (
    tester,
  ) async {
    var newMessage = false;
    var read = 0;
    final api = ChatApi(
      credentials,
      MockClient((request) async {
        if (request.method == 'POST') {
          read =
              (jsonDecode(request.body) as Map<String, dynamic>)['message_id']
                  as int;
          return http.Response(jsonEncode({'read_id': read}), 200);
        }
        final after =
            int.tryParse(request.url.queryParameters['after_id'] ?? '0') ?? 0;
        return snapshot(
          [
            if (after < 1) message(1, 'inviter'),
            if (newMessage && after < 2)
              message(2, 'invitee', clientID: 'partner-message'),
          ],
          latest: newMessage ? 2 : 1,
          read: read,
          unread: newMessage && read < 2 ? 1 : 0,
        );
      }),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPawmateTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PairedHomePage(
          verifySession: false,
          chatStore: Future.value(
            MemoryChatStore(
              ChatScope(
                serverURL: credentials.serverURL,
                pairID: credentials.pairID,
                role: credentials.role,
              ),
            ),
          ),
          credentials: credentials,
          session: const PairingSession(
            role: 'inviter',
            status: 'paired',
            pairID: 'our-home',
          ),
          chatApi: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<AppBar>(find.byType(AppBar)).title, isNull);
    expect(find.byType(CoupleHeaderAvatars), findsOneWidget);
    expect(find.byType(DevicesCard), findsNothing);
    await tester.enterText(find.byType(TextField), 'An unfinished message');
    await tester.tap(find.byTooltip('Games together'));
    await tester.pumpAndSettle();
    expect(tester.widget<AppBar>(find.byType(AppBar)).title, isNull);
    expect(find.byType(CoupleHeaderAvatars), findsOneWidget);
    await tester.tap(find.byTooltip('Life'));
    await tester.pumpAndSettle();
    expect(tester.widget<AppBar>(find.byType(AppBar)).title, isNull);
    expect(find.byType(CoupleHeaderAvatars), findsOneWidget);
    newMessage = true;
    expect(find.byKey(const ValueKey('life-empty-content')), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(read, 0);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('1 unread messages from your partner'), findsOneWidget);
    await tester.tap(find.byTooltip('Chat, 1 unread messages'));
    await tester.pumpAndSettle();
    expect(read, 2);
    expect(find.text('An unfinished message'), findsOneWidget);
    expect(find.text('1'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'avatar entry moves details out of Life and preserves chat reads',
    (tester) async {
      var incoming = false;
      var read = 0;
      var deviceRequests = 0;
      http.Response respond(http.Request request) {
        if (request.url.path.endsWith('/devices')) {
          deviceRequests++;
          return http.Response(jsonEncode({'devices': []}), 200);
        }
        if (request.url.path.endsWith('/session')) {
          return http.Response(
            jsonEncode({
              'role': 'inviter',
              'status': 'paired',
              'pair_id': 'our-home',
            }),
            200,
          );
        }
        if (request.method == 'POST') {
          read =
              (jsonDecode(request.body) as Map<String, dynamic>)['message_id']
                  as int;
          return http.Response(jsonEncode({'read_id': read}), 200);
        }
        return snapshot(
          [if (incoming) message(1, 'invitee')],
          latest: incoming ? 1 : 0,
          unread: incoming && read == 0 ? 1 : 0,
          read: read,
        );
      }

      await http.runWithClient(() async {
        final api = ChatApi(
          credentials,
          MockClient((request) async => respond(request)),
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: buildPawmateTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PairedHomePage(
              chatStore: Future.value(
                MemoryChatStore(
                  ChatScope(
                    serverURL: credentials.serverURL,
                    pairID: credentials.pairID,
                    role: credentials.role,
                  ),
                ),
              ),
              credentials: credentials,
              session: const PairingSession(
                role: 'inviter',
                status: 'paired',
                pairID: 'our-home',
              ),
              recoveryCodeToSave: 'test-recovery-code',
              chatApi: api,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(deviceRequests, 0);
        expect(find.byType(DevicesCard), findsNothing);
        await tester.enterText(find.byType(TextField), 'Keep this draft');
        await tester.tap(find.byTooltip('Life'));
        await tester.pumpAndSettle();
        expect(find.byType(MaterialBanner), findsNothing);
        expect(find.byType(RecoveryCodeNote), findsNothing);
        expect(find.text('Private server'), findsNothing);

        await tester.tap(find.byType(CoupleHeaderButton));
        await tester.pumpAndSettle();
        expect(find.byType(CoupleDetailsPage), findsOneWidget);
        expect(find.text('Private server'), findsOneWidget);
        expect(find.byType(RecoveryCodeNote), findsOneWidget);
        expect(find.byType(DevicesCard), findsOneWidget);
        expect(deviceRequests, 1);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('life-empty-content')),
          findsOneWidget,
        );
        expect(find.byType(CoupleDetailsPage), findsNothing);

        await tester.tap(find.byTooltip('Chat'));
        await tester.pumpAndSettle();
        expect(find.text('Keep this draft'), findsOneWidget);
        await tester.tap(find.byType(CoupleHeaderButton));
        await tester.pumpAndSettle();
        incoming = true;
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(read, 0);
        expect(
          find.text('1 unread messages from your partner'),
          findsOneWidget,
        );
        await tester.tap(find.text('Open chat'));
        await tester.pumpAndSettle();
        expect(find.byType(CoupleDetailsPage), findsNothing);
        expect(read, 1);
        expect(find.text('Keep this draft'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }, () => MockClient((request) async => respond(request)));
    },
  );
}
