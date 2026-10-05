import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pawmate/features/chat/chat_api.dart';
import 'package:pawmate/features/chat/chat_controller.dart';
import 'package:pawmate/features/chat/chat_page.dart';
import 'package:pawmate/features/chat/chat_attachment_view.dart';
import 'package:pawmate/design/theme/pawmate_theme.dart';
import 'package:pawmate/l10n/generated/app_localizations.dart';
import 'package:pawmate/features/chat/storage/chat_store.dart';
import 'package:pawmate/features/chat/storage/native_chat_store.dart';
import 'package:pawmate/features/pairing/pairing_credentials.dart';

const credentials = SavedPairingCredentials(
  serverURL: 'https://home.example.test',
  accessToken: 'private-token',
  recoveryCode: 'private-recovery',
  pairID: 'pair',
  role: 'inviter',
);
final scope = ChatScope(
  serverURL: 'https://home.example.test',
  pairID: 'pair',
  role: 'inviter',
);
final bytes = Uint8List.fromList(utf8.encode('Private file content'));
ChatAttachment metadata({int id = 1}) => ChatAttachment(
  messageID: id,
  kind: 'file',
  name: 'notes.txt',
  contentType: 'application/octet-stream',
  size: bytes.length,
  digest: sha256.convert(bytes).toString(),
);
ChatMessage message() => ChatMessage(
  id: 1,
  clientID: 'stable-id',
  sender: 'inviter',
  text: 'notes.txt',
  createdAt: DateTime.utc(2026, 10, 6),
  attachment: metadata(),
);

void main() {
  testWidgets(
    'file selection queues content while preserving draft and quiet controls',
    (tester) async {
      final controller = ChatController(
        ChatApi(
          credentials,
          MockClient((_) async => throw StateError('Offline')),
        ),
        requireVerification: true,
      );
      await controller.initialize();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildPawmateTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChatPage(
              controller: controller,
              active: false,
              attachmentPicker: (_, _) async =>
                  AttachmentUpload(metadata(id: 0), bytes),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Keep my draft');
      await tester.tap(find.byTooltip('More chat features'));
      await tester.pumpAndSettle();
      expect(find.textContaining('planned'), findsNothing);
      await tester.tap(find.text('Send file'));
      await tester.pumpAndSettle();
      expect(controller.outbox.single.upload!.bytes, bytes);
      expect(find.text('Keep my draft'), findsOneWidget);
      expect(find.byType(ChatAttachmentView), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets('cached image and file render offline without layout overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 320, 200),
      Paint()..color = const Color(0xff9dc6d8),
    );
    canvas.drawCircle(
      const Offset(240, 55),
      27,
      Paint()..color = const Color(0xfff3c969),
    );
    canvas.drawOval(
      const Rect.fromLTWH(-50, 115, 400, 170),
      Paint()..color = const Color(0xff9bc7b0),
    );
    final picture = recorder.endRecording();
    final image = await tester.runAsync(() => picture.toImage(320, 200));
    final png = (await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.png),
    ))!.buffer.asUint8List();
    image!.dispose();
    picture.dispose();
    final photo = ChatAttachment(
      messageID: 2,
      kind: 'image',
      name: 'Weekend.png',
      contentType: 'image/png',
      size: png.length,
      digest: sha256.convert(png).toString(),
    );
    final store = MemoryChatStore(scope);
    await store.saveAttachmentBytes(photo.digest, png);
    await store.commit([
      message(),
      ChatMessage(
        id: 2,
        clientID: 'photo',
        sender: 'invitee',
        text: photo.name,
        createdAt: DateTime.utc(2026, 10, 6, 18, 20),
        attachment: photo,
      ),
    ]);
    final controller = ChatController(
      ChatApi(
        credentials,
        MockClient((_) async => throw StateError('No network')),
      ),
      store: Future.value(store),
      requireVerification: true,
    );
    await controller.initialize();
    final capture = Platform.environment['PAWMATE_CAPTURE_PREVIEWS'] == '1';
    if (capture) {
      await tester.runAsync(() async {
        final data = ByteData.sublistView(
          await File(
            Platform.environment['PAWMATE_PREVIEW_FONT']!,
          ).readAsBytes(),
        );
        await (FontLoader(
          'PawmatePreview',
        )..addFont(Future.value(data))).load();
      });
    }
    final key = GlobalKey();
    final theme = buildPawmateTheme();
    await tester.pumpWidget(
      MaterialApp(
        theme: capture
            ? theme.copyWith(
                textTheme: theme.textTheme.apply(fontFamily: 'PawmatePreview'),
              )
            : theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (_, child) => RepaintBoundary(key: key, child: child!),
        home: Scaffold(body: ChatPage(controller: controller, active: false)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(ChatAttachmentView), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    if (capture) {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final screenshot = await boundary.toImage(pixelRatio: 2);
        final data = await screenshot.toByteData(
          format: ui.ImageByteFormat.png,
        );
        await File(
          '/tmp/pawmate-chat-attachments.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        screenshot.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  test('metadata rejects unsafe names and mismatched message identity', () {
    for (final name in ['../secret', '..', '.', 'unsafe\u0085name']) {
      expect(
        () => ChatAttachment.fromJson({...metadata().toJson(), 'name': name}),
        throwsFormatException,
      );
    }
    expect(
      () => ChatMessage.fromJson({...message().toJson(), 'id': 2}),
      throwsFormatException,
    );
    expect(
      ChatMessage.fromJson(message().toJson()).attachment!.digest,
      metadata().digest,
    );
  });

  test(
    'upload uses authenticated multipart and stable retry identity',
    () async {
      final api = ChatApi(
        credentials,
        MockClient((request) async {
          expect(request.url.path, '/api/v1/chat/attachments');
          expect(request.url.query, isEmpty);
          expect(request.headers['authorization'], 'Bearer private-token');
          expect(
            request.headers['content-type'],
            startsWith('multipart/form-data'),
          );
          final body = utf8.decode(request.bodyBytes);
          expect(body, contains('stable-id'));
          expect(body, contains('notes.txt'));
          expect(body, contains('Private file content'));
          expect(body, isNot(contains('private-token')));
          return http.Response(jsonEncode(message().toJson()), 200);
        }),
      );
      addTearDown(api.close);
      final result = await api.sendAttachment(
        'stable-id',
        AttachmentUpload(metadata(id: 0), bytes),
      );
      expect(result.attachment!.messageID, 1);
    },
  );

  test('downloads verify length and digest before returning bytes', () async {
    for (final content in [
      bytes,
      Uint8List.fromList([1]),
      Uint8List(bytes.length),
      Uint8List(bytes.length + 1),
    ]) {
      final api = ChatApi(
        credentials,
        MockClient((request) async {
          expect(request.url.path, '/api/v1/chat/attachments/1');
          expect(request.headers['authorization'], 'Bearer private-token');
          return http.Response.bytes(content, 200);
        }),
      );
      if (identical(content, bytes)) {
        expect(await api.downloadAttachment(metadata()), bytes);
      } else {
        await expectLater(
          api.downloadAttachment(metadata()),
          throwsFormatException,
        );
      }
      api.close();
    }
  });

  for (final native in [false, true]) {
    test(
      '${native ? 'SQLite' : 'Memory'} stores pending bytes and imports metadata without authority',
      () async {
        final ChatStore store = native
            ? SqliteChatStore(scope, NativeDatabase.memory())
            : MemoryChatStore(scope);
        addTearDown(store.close);
        await store.putOutgoing(
          StoredOutgoing(
            'stable-id',
            'notes.txt',
            upload: AttachmentUpload(metadata(id: 0), bytes),
          ),
        );
        expect((await store.outbox()).single.upload!.bytes, bytes);
        await store.saveAttachmentBytes(metadata().digest, bytes);
        expect(await store.attachmentBytes(metadata().digest), bytes);
        final batch = ChatHistoryBatch(
          serverURL: credentials.serverURL,
          pairID: 'pair',
          messages: [message()],
        );
        expect(await store.importHistory(batch), 1);
        expect((await store.messages()).single.attachment!.name, 'notes.txt');
        expect((await store.messages()).single.serverConfirmed, isFalse);
        expect((await store.syncState()).afterID, 0);
        expect((await store.outbox()).single.clientID, 'stable-id');
        final exported = (await store.exportHistory()).toJson();
        expect(jsonEncode(exported), isNot(contains('Private file content')));
        expect(
          ChatHistoryBatch.fromJson(
            exported,
          ).messages.single.attachment!.digest,
          metadata().digest,
        );
      },
    );
  }

  test('encrypted attachment outbox and content survive reopening', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pawmate-attachment-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/chat.db');
    final key = List.filled(64, 'a').join();
    var store = SqliteChatStore.encrypted(scope, file, key);
    await store.putOutgoing(
      StoredOutgoing(
        'stable-id',
        'notes.txt',
        upload: AttachmentUpload(metadata(id: 0), bytes),
      ),
    );
    await store.saveAttachmentBytes(metadata().digest, bytes);
    await store.commit([message()]);
    // Restore an unacknowledged upload separately from the confirmed message.
    await store.putOutgoing(
      StoredOutgoing(
        'another-id',
        'notes.txt',
        upload: AttachmentUpload(metadata(id: 0), bytes),
      ),
    );
    await store.close();
    expect(
      utf8.decode(await file.readAsBytes(), allowMalformed: true),
      isNot(contains('Private file content')),
    );
    store = SqliteChatStore.encrypted(scope, file, key);
    expect((await store.outbox()).single.clientID, 'another-id');
    expect((await store.outbox()).single.upload!.bytes, bytes);
    expect(
      (await store.messages()).single.attachment!.digest,
      metadata().digest,
    );
    expect(await store.attachmentBytes(metadata().digest), bytes);
    await store.close();
  });

  test(
    'offline controller restores upload identity and cached content without network',
    () async {
      final store = MemoryChatStore(scope);
      await store.putOutgoing(
        StoredOutgoing(
          'stable-id',
          'notes.txt',
          upload: AttachmentUpload(metadata(id: 0), bytes),
        ),
      );
      await store.saveAttachmentBytes(metadata().digest, bytes);
      var requests = 0;
      final controller = ChatController(
        ChatApi(
          credentials,
          MockClient((_) async {
            requests++;
            throw StateError('Must remain offline');
          }),
        ),
        store: Future.value(store),
        requireVerification: true,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(controller.outbox.single.clientID, 'stable-id');
      expect(controller.outbox.single.upload!.bytes, bytes);
      expect(await controller.attachmentData(metadata()), bytes);
      await expectLater(
        controller.importAttachmentBytes(metadata(), Uint8List(1)),
        throwsFormatException,
      );
      expect(requests, 0);
    },
  );
}
