import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate/design/components/chat_message_bubble.dart';
import 'package:pawmate/design/icons/chat/message_status_icon.dart';
import 'package:pawmate/design/theme/pawmate_theme.dart';
import 'package:pawmate/design/theme/colors.dart';
import 'package:pawmate/l10n/generated/app_localizations.dart';

Widget application(Widget child, {double scale = 1, bool preview = false}) =>
    MaterialApp(
      theme: preview
          ? buildPawmateTheme().copyWith(
              textTheme: buildPawmateTheme().textTheme.apply(
                fontFamily: 'PawmatePreview',
              ),
            )
          : buildPawmateTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: child,
        ),
      ),
    );

void main() {
  testWidgets(
    'compact text keeps time inline without visible identity or state labels',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        application(
          ChatMessageBubble(
            text: 'Hi',
            own: true,
            status: 'Read',
            time: DateTime(2026, 10, 6, 12, 5),
            delivery: MessageDelivery.read,
          ),
        ),
      );
      expect(find.text('You'), findsNothing);
      expect(find.text('Your partner'), findsNothing);
      expect(find.text('Read'), findsNothing);
      expect(find.text('12:05 pm'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('12:05 pm, Read')), findsOneWidget);
      final surface = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is ChatBubblePainter,
      );
      expect(tester.getSize(surface).height, lessThan(44));
      expect(tester.getSize(surface).width, lessThan(200));
      semantics.dispose();
    },
  );

  testWidgets(
    'wrapped Latin, Chinese and unbroken text keeps metadata after the last glyph',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final scale in [1.0, 2.0]) {
        for (final text in [
          'This is a longer message with a final word to keep beside the time',
          '我们今天一起吃晚饭吧这是一条比较长的聊天消息测试最后一行的发送时间',
          'abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz',
          'First line\nFinal line',
          'Emoji at the end 👩‍❤️‍👨',
        ]) {
          await tester.pumpWidget(
            application(
              ChatMessageBubble(
                text: text,
                own: true,
                status: 'Unread',
                time: DateTime(2026, 10, 6, 0, 5),
                delivery: MessageDelivery.sent,
              ),
              scale: scale,
            ),
          );
          final glyph = tester.getRect(
            find.byKey(const ValueKey('message-final-text')),
          );
          final time = tester.getRect(find.text('12:05 am'));
          expect(time.top, lessThan(glyph.bottom), reason: '$scale $text');
          expect(time.bottom, greaterThan(glyph.top), reason: '$scale $text');
          expect(
            time.left,
            greaterThanOrEqualTo(glyph.right),
            reason: '$scale $text',
          );
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'failed message uses a retryable exclamation with keyboard access',
    (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        application(
          ChatMessageBubble(
            text: 'Retry me',
            own: true,
            status: 'Not sent',
            time: DateTime(2026, 10, 6, 9),
            delivery: MessageDelivery.failed,
            onRetry: () => retries++,
          ),
        ),
      );
      await tester.tapAt(tester.getCenter(find.text('9:00 am')));
      expect(retries, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(retries, 2);
      expect(find.text('Not sent'), findsNothing);
    },
  );

  test('directional path mirrors and joined corners have no tail', () {
    const size = Size(180, 45);
    final incoming = const ChatBubblePainter(
      own: false,
      isGroupEnd: true,
    ).outline(size);
    final outgoing = const ChatBubblePainter(
      own: true,
      isGroupEnd: true,
    ).outline(size);
    final joined = const ChatBubblePainter(
      own: false,
      isGroupEnd: false,
    ).outline(size);
    expect(incoming.contains(const Offset(2, 43.8)), isTrue);
    expect(outgoing.contains(const Offset(178, 43.8)), isTrue);
    expect(joined.contains(const Offset(2, 43.8)), isFalse);
    for (var x = 2.0; x < 180; x += 7) {
      for (var y = 2.0; y < 45; y += 7) {
        expect(
          incoming.contains(Offset(x, y)),
          outgoing.contains(Offset(180 - x, y)),
        );
      }
    }
  });

  testWidgets(
    'capture compact message states and grouped tails',
    (tester) async {
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
      });
      final key = GlobalKey();
      await tester.pumpWidget(
        application(
          RepaintBoundary(
            key: key,
            child: Container(
              color: PawmateColors.paper,
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  ChatMessageBubble(
                    text: '今晚一起做饭吧',
                    own: false,
                    status: '',
                    time: DateTime(2026, 10, 6, 18, 20),
                    isGroupEnd: false,
                  ),
                  ChatMessageBubble(
                    text: '想吃番茄炒蛋，还有你上次做的汤',
                    own: false,
                    status: '',
                    time: DateTime(2026, 10, 6, 18, 21),
                  ),
                  ChatMessageBubble(
                    text: '好呀，我下班路上买菜',
                    own: true,
                    status: 'Read',
                    delivery: MessageDelivery.read,
                    time: DateTime(2026, 10, 6, 18, 22),
                    isGroupEnd: false,
                  ),
                  ChatMessageBubble(
                    text:
                        'Do we still have tomatoes? I can pick up some fresh ones on the way home',
                    own: true,
                    status: 'Unread',
                    delivery: MessageDelivery.sent,
                    time: DateTime(2026, 10, 6, 18, 23),
                  ),
                  ChatMessageBubble(
                    text: '还要买牛奶',
                    own: true,
                    status: 'Not sent',
                    delivery: MessageDelivery.failed,
                    time: DateTime(2026, 10, 6, 18, 30),
                    onRetry: () {},
                  ),
                ],
              ),
            ),
          ),
          preview: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        await File(
          '/tmp/pawmate-chat-bubbles-after.png',
        ).writeAsBytes(data!.buffer.asUint8List());
      });
    },
    skip: !const bool.fromEnvironment('PAWMATE_CAPTURE_PREVIEWS'),
  );
}
