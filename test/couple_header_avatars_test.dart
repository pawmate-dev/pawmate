import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pawmate/design/components/couple_header_avatars.dart';
import 'package:pawmate/design/icons/profile/profile_doodle_icon.dart';
import 'package:pawmate/design/layouts/handdrawn_scaffold.dart';
import 'package:pawmate/design/theme/colors.dart';
import 'package:pawmate/design/theme/pawmate_theme.dart';
import 'package:pawmate/design/icons/navigation/navigation_doodle_icon.dart';
import 'package:pawmate/features/pairing/couple_details_page.dart';
import 'package:pawmate/features/pairing/member_profile.dart';
import 'package:pawmate/features/pairing/pairing_api.dart';
import 'package:pawmate/features/pairing/pairing_credentials.dart';
import 'package:pawmate/l10n/generated/app_localizations.dart';

/// Creates a synthetic portrait without reading anyone's private profile.
Future<Uint8List> portrait(Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(color, BlendMode.src);
  final ink = Paint()..color = PawmateColors.ink;
  canvas.drawCircle(const Offset(22, 27), 3, ink);
  canvas.drawCircle(const Offset(42, 27), 3, ink);
  canvas.drawArc(
    const Rect.fromLTWH(22, 32, 20, 12),
    0,
    3.14,
    false,
    ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(64, 64);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}

/// Embeds the header in the same native paper app bar as the couple space.
Widget header({
  Uint8List? member,
  Uint8List? partner,
  TextDirection direction = TextDirection.ltr,
  GlobalKey? captureKey,
}) => MaterialApp(
  theme: buildPawmateTheme(),
  home: Directionality(
    textDirection: direction,
    child: RepaintBoundary(
      key: captureKey,
      child: HanddrawnScaffold(
        title: null,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: CoupleHeaderAvatars(
                memberAvatar: member,
                partnerAvatar: partner,
                memberNickname: 'Ash',
                partnerNickname: 'Sunny',
                memberLabel: 'Your profile',
                partnerLabel: 'Partner profile',
              ),
            ),
          ),
        ],
        body: const SizedBox.shrink(),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'details reuse overlapping portraits without Life icon or role text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final member = (await tester.runAsync(
        () => portrait(PawmateColors.rose),
      ))!;
      final partner = (await tester.runAsync(
        () => portrait(PawmateColors.mint),
      ))!;
      final key = GlobalKey();
      final previewFont = const bool.fromEnvironment('PAWMATE_CAPTURE_PREVIEWS')
          ? Platform.environment['PAWMATE_PREVIEW_FONT']
          : null;
      if (previewFont != null) {
        await tester.runAsync(() async {
          final bytes = ByteData.sublistView(
            await File(previewFont).readAsBytes(),
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
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: previewFont == null
                    ? buildPawmateTheme()
                    : buildPawmateTheme().copyWith(
                        textTheme: buildPawmateTheme().textTheme.apply(
                          fontFamily: 'PawmatePreview',
                        ),
                      ),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: CoupleDetailsPage(
                  credentials: const SavedPairingCredentials(
                    serverURL: 'https://preview.example.test',
                    accessToken: 'preview-token',
                    recoveryCode: '',
                    pairID: 'preview-pair',
                    role: 'inviter',
                  ),
                  session: PairingSession(
                    role: 'inviter',
                    status: 'paired',
                    pairID: 'preview-pair',
                    profile: MemberProfile(nickname: 'Ash', avatar: member),
                    partner: MemberProfile(nickname: 'Sunny', avatar: partner),
                  ),
                ),
              ),
            ),
          );
          await tester.runAsync(() async {
            await precacheImage(MemoryImage(member), key.currentContext!);
            await precacheImage(MemoryImage(partner), key.currentContext!);
          });
          await tester.pumpAndSettle();
          expect(find.byType(NavigationDoodleIcon), findsNothing);
          expect(find.text('You'), findsNothing);
          expect(find.text('Your partner'), findsNothing);
          final pair = tester.widget<CoupleHeaderAvatars>(
            find.byType(CoupleHeaderAvatars),
          );
          expect(pair.size, 80);
          final left = tester.getRect(find.byTooltip('You: Ash'));
          final right = tester.getRect(find.byTooltip('Your partner: Sunny'));
          expect(left.left, lessThan(right.left));
          expect(left.right - right.left, closeTo(80 * 8 / 44, 0.01));
          expect(left.height, 80);
          expect(find.text('Private server'), findsOneWidget);
          expect(find.text('My devices'), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (const bool.fromEnvironment('PAWMATE_CAPTURE_PREVIEWS')) {
            await tester.runAsync(() async {
              final boundary =
                  key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              image.dispose();
              await File(
                '/tmp/pawmate-couple-details.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
            });
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
        () => MockClient(
          (_) async => http.Response(jsonEncode({'devices': []}), 200),
        ),
      );
    },
  );

  testWidgets('the whole pair is one accessible keyboard-activated action', (
    tester,
  ) async {
    var opens = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPawmateTheme(),
        home: Scaffold(
          body: Center(
            child: CoupleHeaderButton(
              label: 'Open couple details',
              onPressed: () => opens++,
              child: const CoupleHeaderAvatars(
                memberLabel: 'You',
                partnerLabel: 'Partner',
              ),
            ),
          ),
        ),
      ),
    );
    final semantics = tester.ensureSemantics();
    final node = tester.getSemantics(
      find.bySemanticsLabel('Open couple details'),
    );
    expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
    expect(node.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
    expect(
      tester.getSize(find.byType(TextButton)).height,
      greaterThanOrEqualTo(44),
    );
    final button = tester.widget<TextButton>(find.byType(TextButton));
    expect(
      button.style!.overlayColor!.resolve({WidgetState.pressed}),
      Colors.transparent,
    );
    await tester.tap(find.byTooltip('Open couple details'));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(opens, 2);
    semantics.dispose();
  });

  testWidgets(
    'header omits title and uses two upload-style frames without plus',
    (tester) async {
      await tester.pumpWidget(header());
      expect(tester.widget<AppBar>(find.byType(AppBar)).title, isNull);
      final painters = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((widget) => widget.foregroundPainter)
          .whereType<ProfileDoodlePainter>();
      expect(painters, hasLength(2));
      expect(painters.every((painter) => !painter.showPlus), isTrue);
      expect(find.byTooltip('Your profile: Ash'), findsOneWidget);
      expect(find.byTooltip('Partner profile: Sunny'), findsOneWidget);
      expect(find.text('Ash'), findsNothing);
      final bounds = tester.getRect(find.byType(CoupleHeaderAvatars));
      expect(bounds.width, 80);
      expect(bounds.height, 44);
      expect(bounds.right, tester.getRect(find.byType(AppBar)).right - 16);
    },
  );

  testWidgets(
    'left portrait is painted last with only a small overlap in LTR/RTL',
    (tester) async {
      for (final direction in TextDirection.values) {
        await tester.pumpWidget(header(direction: direction));
        final stack = tester.widget<Stack>(
          find.descendant(
            of: find.byType(CoupleHeaderAvatars),
            matching: find.byType(Stack),
          ),
        );
        expect((stack.children.first as Positioned).right, 0);
        expect((stack.children.last as Positioned).left, 0);
        final left = tester.getRect(find.byTooltip('Your profile: Ash'));
        final right = tester.getRect(find.byTooltip('Partner profile: Sunny'));
        expect(left.left, lessThan(right.left));
        expect(left.right - right.left, CoupleHeaderAvatars.overlap);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'profiles replace placeholders without exposing upload controls',
    (tester) async {
      final member = (await tester.runAsync(
        () => portrait(PawmateColors.rose),
      ))!;
      final partner = (await tester.runAsync(
        () => portrait(PawmateColors.mint),
      ))!;
      await tester.pumpWidget(header());
      expect(find.byType(Image), findsNothing);
      await tester.pumpWidget(header(member: member, partner: partner));
      await tester.runAsync(() async {
        final context = tester.element(find.byType(CoupleHeaderAvatars));
        await precacheImage(MemoryImage(member), context);
        await precacheImage(MemoryImage(partner), context);
      });
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNWidgets(2));
      expect(find.byType(IconButton), findsNothing);
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Your profile: Ash'), findsOneWidget);
      expect(find.bySemanticsLabel('Partner profile: Sunny'), findsOneWidget);
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'capture synthetic couple header preview',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 80));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final key = GlobalKey();
      final member = (await tester.runAsync(
        () => portrait(PawmateColors.rose),
      ))!;
      final partner = (await tester.runAsync(
        () => portrait(PawmateColors.mint),
      ))!;
      await tester.pumpWidget(
        header(member: member, partner: partner, captureKey: key),
      );
      await tester.runAsync(() async {
        await precacheImage(MemoryImage(member), key.currentContext!);
        await precacheImage(MemoryImage(partner), key.currentContext!);
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 3);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        await File(
          '/tmp/pawmate-couple-header.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      });
    },
    skip: !const bool.fromEnvironment('PAWMATE_CAPTURE_PREVIEWS'),
  );
}
