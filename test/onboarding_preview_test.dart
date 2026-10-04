import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate/design/components/handdrawn_button.dart';
import 'package:pawmate/design/layouts/handdrawn_scaffold.dart';
import 'package:pawmate/design/theme/pawmate_theme.dart';
import 'package:pawmate/features/pairing/login_methods_page.dart';
import 'package:pawmate/features/pairing/widgets/pairing_recovery_card.dart';
import 'package:pawmate/features/pairing/widgets/server_setup_card.dart';
import 'package:pawmate/l10n/generated/app_localizations.dart';

/// Opt-in visual captures using a caller-provided reading font, not test Ahem.
/// Run with PAWMATE_PREVIEW_FONT and --dart-define=PAWMATE_CAPTURE_PREVIEWS=true.
void main() {
  testWidgets(
    'capture previous stacked reference and new access matrix',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fontPath = Platform.environment['PAWMATE_PREVIEW_FONT'];
      expect(
        fontPath,
        isNotNull,
        reason: 'Provide a local reading-font TTF for previews.',
      );
      await tester.runAsync(() async {
        final bytes = await File(fontPath!).readAsBytes();
        final loader = FontLoader('PawmatePreview')
          ..addFont(Future.value(ByteData.sublistView(bytes)));
        await loader.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
      });
      final controllers = List.generate(3, (_) => TextEditingController());
      addTearDown(() {
        for (final controller in controllers) {
          controller.dispose();
        }
      });
      // A non-interactive reconstruction of the former stacked composition.
      final before = HanddrawnScaffold(
        title: 'Invite your partner',
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 18),
              HanddrawnButton(
                label: 'Sign in on another device',
                onPressed: () {},
                primary: false,
                icon: Icons.devices,
              ),
              const SizedBox(height: 20),
              ServerSetupCard(
                formKey: GlobalKey<FormState>(),
                controller: controllers[0],
                isLoading: false,
                onCreateInvite: () {},
              ),
              const SizedBox(height: 18),
              PairingRecoveryCard(
                serverController: controllers[1],
                codeController: controllers[2],
                isLoading: false,
                onRecover: () {},
              ),
            ],
          ),
        ),
      );
      final theme = buildPawmateTheme();
      for (final entry in {
        'login-before': before,
        'login-matrix': const LoginMethodsPage(),
      }.entries) {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: theme.copyWith(
              textTheme: theme.textTheme.apply(fontFamily: 'PawmatePreview'),
            ),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: RepaintBoundary(key: key, child: entry.value),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          await File(
            'books/src/images/${entry.key}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        });
      }
    },
    skip: !const bool.fromEnvironment('PAWMATE_CAPTURE_PREVIEWS'),
  );
}
