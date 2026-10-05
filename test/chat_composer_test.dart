import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pawmate/design/components/chat_composer.dart';
import 'package:pawmate/design/components/crayon_icon_button.dart';
import 'package:pawmate/design/theme/pawmate_theme.dart';
import 'package:pawmate/features/chat/chat_api.dart';
import 'package:pawmate/features/chat/chat_controller.dart';
import 'package:pawmate/features/chat/chat_page.dart';
import 'package:pawmate/features/pairing/pairing_credentials.dart';
import 'package:pawmate/l10n/generated/app_localizations.dart';

Widget application(Widget child, {Locale locale = const Locale('en')}) =>
    MaterialApp(
      theme: buildPawmateTheme(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('composer orders actions around a silent native editor', (
    tester,
  ) async {
    final draft = TextEditingController();
    var attachments = 0;
    var stickers = 0;
    var sends = 0;
    String? changed;
    await tester.pumpWidget(
      application(
        ChatComposer(
          controller: draft,
          onChanged: (value) => changed = value,
          onAttachments: () => attachments++,
          onStickers: () => stickers++,
          onSend: () => sends++,
          inputLabel: 'Message your partner',
          attachmentsLabel: 'More chat features',
          stickersLabel: 'Stickers',
          sendLabel: 'Send message',
        ),
      ),
    );
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration, isNull);
    expect(field.cursorOpacityAnimates, isFalse);
    expect(find.byType(InputDecorator), findsNothing);
    expect(find.text('Message your partner'), findsNothing);
    final add = tester.getRect(find.byTooltip('More chat features'));
    final input = tester.getRect(find.byType(TextField));
    final sticker = tester.getRect(find.byTooltip('Stickers'));
    final send = tester.getRect(find.byTooltip('Send message'));
    expect(add.right, lessThan(input.left));
    expect(input.right, lessThan(sticker.left));
    expect(sticker.right, lessThanOrEqualTo(send.left));
    for (final button in tester.widgetList<TextButton>(
      find.byType(TextButton),
    )) {
      expect(button.style!.splashFactory, NoSplash.splashFactory);
      expect(button.style!.animationDuration, Duration.zero);
      expect(
        button.style!.overlayColor!.resolve({WidgetState.pressed}),
        Colors.transparent,
      );
    }
    await tester.enterText(find.byType(TextField), 'Multiline\ndraft');
    expect(changed, 'Multiline\ndraft');
    await tester.tap(find.byTooltip('More chat features'));
    await tester.tap(find.byTooltip('Stickers'));
    await tester.tap(find.byTooltip('Send message'));
    expect([attachments, stickers, sends], [1, 1, 1]);
    expect(draft.text, 'Multiline\ndraft');
    await tester.pumpWidget(const SizedBox.shrink());
    draft.dispose();
  });

  testWidgets(
    'attachment and sticker previews retain drafts without network calls',
    (tester) async {
      const credentials = SavedPairingCredentials(
        serverURL: 'https://home.example.test',
        accessToken: 'token',
        recoveryCode: '',
        pairID: 'pair',
        role: 'inviter',
      );
      var requests = 0;
      final chat = ChatController(
        ChatApi(
          credentials,
          MockClient((_) async {
            requests++;
            throw StateError('No upload should occur');
          }),
        ),
        requireVerification: true,
      );
      await chat.initialize();
      await tester.pumpWidget(
        application(
          ChatPage(
            controller: chat,
            active: false,
            attachmentPicker: (_, _) async => null,
          ),
          locale: const Locale('zh'),
        ),
      );
      await tester.enterText(find.byType(TextField), '保留这个草稿');
      await tester.tap(find.byTooltip('更多聊天功能'));
      await tester.pumpAndSettle();
      expect(find.text('发送文件'), findsOneWidget);
      expect(find.text('发送图片'), findsOneWidget);
      await tester.tap(find.text('发送文件'));
      await tester.pump();
      expect(requests, 0);
      await tester.pumpAndSettle();
      expect(find.text('保留这个草稿'), findsOneWidget);
      await tester.tap(find.byTooltip('表情包'));
      await tester.pumpAndSettle();
      expect(find.text('双人表情包收藏将在后续开放'), findsOneWidget);
      expect(requests, 0);
      expect(chat.outbox, isEmpty);
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      final button = tester.widget<CrayonIconButton>(
        find.ancestor(
          of: find.byTooltip('发送消息'),
          matching: find.byType(CrayonIconButton),
        ),
      );
      expect(button.onPressed, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      chat.dispose();
    },
  );
}
