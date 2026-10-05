import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pawmate/design/theme/pawmate_theme.dart';
import 'package:pawmate/features/chat/chat_api.dart';
import 'package:pawmate/features/chat/storage/chat_store.dart';
import 'package:pawmate/features/pairing/couple_details_page.dart';
import 'package:pawmate/features/pairing/pairing_session_gate.dart';
import 'package:pawmate/features/pairing/settings_page.dart';
import 'package:pawmate/l10n/generated/app_localizations.dart';
import 'package:pawmate/l10n/locale_controller.dart';

/// Mounts locale state above the Navigator so pushed settings routes inherit it.
Widget application(
  LocaleController locales,
  ChatStore store, {
  GlobalKey? previewKey,
}) => ListenableBuilder(
  listenable: locales,
  builder: (_, _) => MaterialApp(
    theme: buildPawmateTheme().copyWith(
      textTheme: const bool.fromEnvironment('PAWMATE_CAPTURE_PREVIEWS')
          ? buildPawmateTheme().textTheme.apply(fontFamily: 'PawmatePreview')
          : null,
    ),
    locale: locales.locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (_, child) => RepaintBoundary(
      key: previewKey,
      child: LocaleControllerScope(notifier: locales, child: child!),
    ),
    home: PairingSessionGate(store: Future.value(store)),
  ),
);

void main() {
  setUp(
    () => FlutterSecureStorage.setMockInitialValues({
      'pawmate.pairing.credentials.v1': jsonEncode({
        'server_url': 'https://offline.example.test',
        'access_token': 'token',
        'recovery_code': '',
        'pair_id': 'pair',
        'role': 'inviter',
      }),
    }),
  );

  testWidgets(
    'cached history opens before server replies, errors stay below toolbar',
    (tester) async {
      final previewKey = GlobalKey();
      if (const bool.fromEnvironment('PAWMATE_CAPTURE_PREVIEWS')) {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.runAsync(() async {
          final bytes = ByteData.sublistView(
            await File(
              Platform.environment['PAWMATE_PREVIEW_FONT']!,
            ).readAsBytes(),
          );
          await (FontLoader(
            'PawmatePreview',
          )..addFont(Future.value(bytes))).load();
          await (FontLoader('monospace')..addFont(Future.value(bytes))).load();
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
        });
      }
      Future<void> capture(String name) async {
        if (!const bool.fromEnvironment('PAWMATE_CAPTURE_PREVIEWS')) return;
        await tester.runAsync(() async {
          final boundary =
              previewKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          await File(
            '/tmp/pawmate-$name.png',
          ).writeAsBytes(data!.buffer.asUint8List());
        });
      }

      final response = Completer<http.Response>();
      final locales = LocaleController();
      final store = MemoryChatStore(
        ChatScope(
          serverURL: 'https://offline.example.test',
          pairID: 'pair',
          role: 'inviter',
        ),
      );
      await store.commit([
        ChatMessage(
          id: 8,
          clientID: 'cached-8',
          sender: 'invitee',
          text: 'Available without a network',
          createdAt: DateTime.utc(2026, 10, 6),
        ),
      ], state: const ChatSyncState(afterID: 8, latestID: 8));
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            application(locales, store, previewKey: previewKey),
          );
          await tester.pumpAndSettle();
          expect(find.text('Available without a network'), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(find.text('Checking your saved access…'), findsNothing);
          response.completeError(const FormatException('unreachable'));
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(
            tester.element(find.byType(AppBar)),
          )!;
          final error = find.text(l10n.connectionOffline);
          expect(error, findsOneWidget);
          await capture('offline-chat');
          expect(
            tester.getTopLeft(error).dy,
            greaterThanOrEqualTo(tester.getBottomLeft(find.byType(AppBar)).dy),
          );
          await tester.tap(find.byTooltip('Life'));
          await tester.pumpAndSettle();
          expect(find.text(l10n.connectionOffline), findsOneWidget);
          await tester.tap(find.byTooltip('Open couple details'));
          await tester.pumpAndSettle();
          expect(find.byType(CoupleDetailsPage), findsOneWidget);
          await tester.scrollUntilVisible(
            find.text('Settings'),
            200,
            scrollable: find
                .descendant(
                  of: find.byType(CoupleDetailsPage),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.tap(find.text('Settings'));
          await tester.pumpAndSettle();
          expect(find.byType(SettingsPage), findsOneWidget);
          await capture('settings');
          expect(
            find.text('Restore access with a recovery code'),
            findsOneWidget,
          );
          expect(find.text('Choose a sign-in method'), findsOneWidget);
          await tester.tap(find.text('简体中文'));
          await tester.pumpAndSettle();
          expect(locales.locale.languageCode, 'zh');
          expect(find.text('设置'), findsOneWidget);
          expect(find.text('服务器连接'), findsOneWidget);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
        () => MockClient(
          (request) async => request.url.path.endsWith('/session')
              ? response.future
              : http.Response(jsonEncode({'devices': []}), 200),
        ),
      );
      locales.dispose();
    },
  );

  testWidgets('revoked credentials do not redirect or erase cached history', (
    tester,
  ) async {
    final locales = LocaleController();
    final store = MemoryChatStore(
      ChatScope(
        serverURL: 'https://offline.example.test',
        pairID: 'pair',
        role: 'inviter',
      ),
    );
    await store.commit([
      ChatMessage(
        id: 1,
        clientID: 'cached',
        sender: 'invitee',
        text: 'Keep this local history',
        createdAt: DateTime.utc(2026, 10, 6),
      ),
    ]);
    await http.runWithClient(() async {
      await tester.pumpWidget(application(locales, store));
      await tester.pumpAndSettle();
      expect(find.text('Keep this local history'), findsOneWidget);
      expect(
        find.text(
          "This device's access has expired. Restore access in Settings",
        ),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'Must not send');
      await tester.pump();
      final send = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Send message'),
          matching: find.byType(IconButton),
        ),
      );
      expect(send.onPressed, isNull);
      expect(find.text('Restore your home'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }, () => MockClient((_) async => http.Response('{}', 401)));
    locales.dispose();
  });
}
