import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate/design/components/crayon_navigation_bar.dart';
import 'package:pawmate/design/icons/navigation/navigation_doodle_icon.dart';
import 'package:pawmate/design/theme/pawmate_theme.dart';
import 'package:pawmate/l10n/generated/app_localizations.dart';

/// Exercises navigation without starting chat polling or contacting a server.
Widget navigation({
  int selected = 0,
  int unread = 0,
  Locale locale = const Locale('en'),
  ValueChanged<int>? onSelected,
}) => MaterialApp(
  theme: buildPawmateTheme(),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      return Scaffold(
        bottomNavigationBar: CrayonNavigationBar(
          selectedIndex: selected,
          onDestinationSelected: onSelected ?? (_) {},
          chatLabel: unread > 0 ? l10n.chatUnread(unread) : l10n.chat,
          gamesLabel: l10n.onlineGames,
          lifeLabel: l10n.life,
          unreadCount: unread,
        ),
      );
    },
  ),
);

void main() {
  testWidgets(
    'icons hide labels while retaining selection and button semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final selections = <int>[];
      await tester.pumpWidget(
        navigation(selected: 2, onSelected: selections.add),
      );
      for (final label in ['Chat', 'Games together', 'Life']) {
        expect(find.text(label), findsNothing);
        final node = tester.getSemantics(find.bySemanticsLabel(label));
        expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
        expect(
          node.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        expect(
          node.getSemanticsData().flagsCollection.isSelected,
          label == 'Life' ? ui.Tristate.isTrue : ui.Tristate.isFalse,
        );
        await tester.tap(find.byTooltip(label));
      }
      expect(selections, [0, 1, 2]);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationDoodleIcon), findsNWidgets(3));
      semantics.dispose();
    },
  );

  testWidgets('Chinese labels and capped unread count work on narrow layouts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(240, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      navigation(unread: 123, locale: const Locale('zh')),
    );
    expect(find.byTooltip('联机小游戏'), findsOneWidget);
    expect(find.byTooltip('生活'), findsOneWidget);
    expect(find.text('生活'), findsNothing);
    expect(find.text('99+'), findsOneWidget);
    for (final button in tester.widgetList<TextButton>(
      find.byType(TextButton),
    )) {
      expect(button.style!.splashFactory, NoSplash.splashFactory);
      expect(
        button.style!.overlayColor!.resolve({WidgetState.pressed}),
        Colors.transparent,
      );
    }
    for (final element in find.byType(TextButton).evaluate()) {
      final size = tester.getSize(find.byWidget(element.widget));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keyboard focus remains visible and Enter selects a destination',
    (tester) async {
      int? selected;
      await tester.pumpWidget(
        navigation(onSelected: (index) => selected = index),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        tester
            .widgetList<NavigationDoodleIcon>(find.byType(NavigationDoodleIcon))
            .where((icon) => icon.focused),
        hasLength(1),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(selected, 0);
    },
  );

  testWidgets(
    'each navigation symbol paints identical pixels after rebuilding',
    (tester) async {
      final key = GlobalKey();
      for (final symbol in NavigationDoodle.values) {
        for (final selected in [false, true]) {
          var generation = 0;
          Widget icon() => MaterialApp(
            home: Center(
              child: RepaintBoundary(
                key: key,
                child: NavigationDoodleIcon(
                  key: ValueKey(generation),
                  symbol: symbol,
                  selected: selected,
                ),
              ),
            ),
          );
          Future<List<int>?> pixels() => tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData();
            image.dispose();
            return bytes!.buffer.asUint8List();
          });
          await tester.pumpWidget(icon());
          await tester.pumpAndSettle();
          final before = await pixels();
          generation++;
          await tester.pumpWidget(icon());
          await tester.pumpAndSettle();
          expect(await pixels(), before);
        }
      }
    },
  );

  testWidgets(
    'capture before and after navigation previews without private data',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final key = GlobalKey();
      for (var selected = -1; selected < 3; selected++) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildPawmateTheme(),
            home: Center(
              child: RepaintBoundary(
                key: key,
                child: selected == -1
                    ? NavigationBar(
                        destinations: const [
                          NavigationDestination(
                            icon: Icon(Icons.chat_bubble_outline),
                            label: 'Chat',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.sports_esports_outlined),
                            label: 'Play',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.home_outlined),
                            label: 'Home',
                          ),
                        ],
                      )
                    : CrayonNavigationBar(
                        selectedIndex: selected,
                        onDestinationSelected: (_) {},
                        chatLabel: 'Chat',
                        gamesLabel: 'Games together',
                        lifeLabel: 'Life',
                      ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 3);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          final name = selected == -1 ? 'before' : 'after-$selected';
          await File(
            '/tmp/pawmate-navigation-$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        });
      }
    },
    skip: !const bool.fromEnvironment('PAWMATE_CAPTURE_PREVIEWS'),
  );
}
