import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:pawmate/main.dart';
import 'package:pawmate/features/pairing/device_login_page.dart';
import 'package:pawmate/design/pawmate_theme.dart';

void main() {
  testWidgets('inviter setup page accepts a server URL', (
    WidgetTester tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const PawmateApp());
    await tester.pumpAndSettle();

    expect(find.text('Invite your partner'), findsOneWidget);
    expect(find.text('Server URL or domain'), findsOneWidget);
    expect(find.text('Create invitation'), findsOneWidget);
    await tester.tap(find.text('Sign in on another device'));
    await tester.pumpAndSettle();
    expect(find.text('Device login code'), findsOneWidget);
    expect(find.text('Device name'), findsOneWidget);
  });

  testWidgets(
    'device login validates input and fits a small screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildPawmateTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const DeviceLoginPage(),
        ),
      );
      await tester.ensureVisible(find.text('Sign in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your server address.'), findsOneWidget);
      expect(find.text('Enter the login code.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
