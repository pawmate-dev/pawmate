import 'package:flutter_test/flutter_test.dart';

import 'package:pawmate/main.dart';

void main() {
  testWidgets('inviter setup page accepts a server URL', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PawmateApp());

    expect(find.text('Invite your partner'), findsOneWidget);
    expect(find.text('Server URL or domain'), findsOneWidget);
    expect(find.text('Create invitation'), findsOneWidget);
  });
}
