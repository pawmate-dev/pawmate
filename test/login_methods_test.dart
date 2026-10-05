import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pawmate/design/components/handdrawn_action_card.dart';
import 'package:pawmate/design/icons/access/access_doodle_icon.dart';
import 'package:pawmate/design/theme/pawmate_theme.dart';
import 'package:pawmate/features/pairing/invitation_link.dart';
import 'package:pawmate/features/pairing/login_methods_page.dart';
import 'package:pawmate/l10n/generated/app_localizations.dart';

const invitation =
    'pawmate://pair?server=http%3A%2F%2F100.64.0.1%3A8080&code=one-time-code';

/// Builds the landing screen directly without startup network requests.
Widget landing({double textScale = 1}) => MaterialApp(
  theme: buildPawmateTheme(),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: const LoginMethodsPage(),
);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('development builds accept HTTP and HTTPS invitation URLs', () {
    expect(
      InvitationLink.parse(' $invitation ').queryParameters['server'],
      'http://100.64.0.1:8080',
    );
    expect(
      InvitationLink.parse(
        'pawmate://pair?server=https%3A%2F%2Fhome.example.test&code=abc',
      ).host,
      'pair',
    );
    for (final value in [
      '',
      'https://example.test',
      'pawmate://pair?code=abc',
      'pawmate://pair?server=http%3A%2F%2Fhost&code=',
      '$invitation&code=second-code',
      '$invitation&server=http%3A%2F%2Fother',
      '$invitation#fragment',
      'pawmate://user:secret@pair?server=http%3A%2F%2Fhost&code=abc',
      'pawmate://pair?server=ftp%3A%2F%2Fhost&code=abc',
      'pawmate://pair?server=https%3A%2F%2Fuser%3Asecret%40host&code=abc',
      'pawmate://pair/wrong?server=http%3A%2F%2Fhost&code=abc',
    ]) {
      expect(
        () => InvitationLink.parse(value),
        throwsFormatException,
        reason: value,
      );
    }
  });

  testWidgets('four access cards occupy two rows and two columns', (
    tester,
  ) async {
    await tester.pumpWidget(landing());
    final cards = find.byType(HanddrawnActionCard);
    expect(cards, findsNWidgets(4));
    expect(find.byType(AccessDoodleIcon), findsNWidgets(4));
    final first = tester.getRect(cards.at(0));
    final second = tester.getRect(cards.at(1));
    final third = tester.getRect(cards.at(2));
    final fourth = tester.getRect(cards.at(3));
    expect(first.top, second.top);
    expect(third.top, fourth.top);
    expect(first.left, third.left);
    expect(second.left, fourth.left);
    expect(third.top, greaterThan(first.bottom));
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets(
    'small screens preserve the matrix and large text without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(landing(textScale: 2));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Restore data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore data'));
      await tester.pumpAndSettle();
      expect(find.text('Restore your home'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Recovery code'), 300);
      await tester.pumpAndSettle();
      expect(find.text('Recovery code'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'invitation input validates before navigating and requires review',
    (tester) async {
      await tester.pumpWidget(landing());
      await tester.tap(find.text('Accept invitation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review invitation'));
      await tester.pumpAndSettle();
      expect(find.text('This invitation link is not valid.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), invitation);
      await tester.tap(find.text('Review invitation'));
      await tester.pumpAndSettle();
      expect(find.text('You have been invited'), findsOneWidget);
      expect(find.text('http://100.64.0.1:8080'), findsOneWidget);
      expect(find.text('Accept invitation'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text(invitation), findsOneWidget);
    },
  );

  testWidgets('clipboard is read only after pressing Paste link', (
    tester,
  ) async {
    var reads = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.getData') {
          reads++;
          return {'text': invitation};
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(landing());
    await tester.tap(find.text('Accept invitation'));
    await tester.pumpAndSettle();
    expect(reads, 0);
    await tester.tap(find.text('Paste link'));
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect(find.text(invitation), findsOneWidget);
    expect(find.text('You have been invited'), findsNothing);
  });

  testWidgets('access cards expose button semantics and keyboard activation', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(landing());
    expect(find.bySemanticsLabel('Accept invitation'), findsOneWidget);
    final node = tester.getSemantics(
      find.bySemanticsLabel('Accept invitation'),
    );
    expect(node.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    // The language control now precedes the access cards in focus order.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Server URL or domain'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('crayon pixels remain identical after rebuilding each purpose', (
    tester,
  ) async {
    final key = GlobalKey();
    for (final symbol in AccessDoodle.values) {
      var generation = 0;
      Widget icon() => MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: AccessDoodleIcon(key: ValueKey(generation), symbol: symbol),
          ),
        ),
      );
      await tester.pumpWidget(icon());
      await tester.pumpAndSettle();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final before = await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData();
        image.dispose();
        return bytes!.buffer.asUint8List();
      });
      generation++;
      await tester.pumpWidget(icon());
      await tester.pumpAndSettle();
      final after = await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData();
        image.dispose();
        return bytes!.buffer.asUint8List();
      });
      expect(after, before);
    }
  });
}
