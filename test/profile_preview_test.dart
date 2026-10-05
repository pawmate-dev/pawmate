import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate/design/theme/pawmate_theme.dart';
import 'package:pawmate/features/pairing/invitee_accept_page.dart';
import 'package:pawmate/features/pairing/inviter_setup_page.dart';
import 'package:pawmate/l10n/generated/app_localizations.dart';

/// Opt-in native-widget previews using a real reading font instead of Ahem.
void main() {
  testWidgets(
    'capture member identity onboarding in both languages',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        final font = FontLoader('PawmatePreview')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                await File(
                  Platform.environment['PAWMATE_PREVIEW_FONT']!,
                ).readAsBytes(),
              ),
            ),
          );
        await font.load();
        final monospace = FontLoader('monospace')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                await File(
                  Platform.environment['PAWMATE_PREVIEW_MONO_FONT'] ??
                      Platform.environment['PAWMATE_PREVIEW_FONT']!,
                ).readAsBytes(),
              ),
            ),
          );
        await monospace.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
      });
      final theme = buildPawmateTheme();
      for (final language in ['en', 'zh']) {
        for (final entry in {
          'inviter': const InviterSetupPage(),
          'accept': InviteeAcceptPage(
            inviteUri: Uri.parse(
              'pawmate://pair?server=https%3A%2F%2Fhome.example.test&code=preview',
            ),
          ),
        }.entries) {
          final key = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: Locale(language),
              theme: theme.copyWith(
                textTheme: theme.textTheme.apply(fontFamily: 'PawmatePreview'),
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: RepaintBoundary(key: key, child: entry.value),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            try {
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                'books/src/images/profile-${entry.key}-$language.png',
              ).writeAsBytes(data!.buffer.asUint8List());
            } finally {
              image.dispose();
            }
          });
          await tester.pumpWidget(const SizedBox());
        }
      }
    },
    skip: !const bool.fromEnvironment('PAWMATE_CAPTURE_PREVIEWS'),
  );
}
