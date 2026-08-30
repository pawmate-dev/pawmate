import 'package:flutter/material.dart';

import 'features/pairing/inviter_setup_page.dart';

void main() {
  runApp(const PawmateApp());
}

/// Root widget for the Pawmate Flutter application.
class PawmateApp extends StatelessWidget {
  const PawmateApp({super.key});

  /// Configures the app theme and starts the inviter onboarding flow.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pawmate',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const InviterSetupPage(),
    );
  }
}
