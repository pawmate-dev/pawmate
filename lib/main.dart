import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';

import 'design/pawmate_theme.dart';
import 'features/pairing/invitee_accept_page.dart';
import 'features/pairing/inviter_setup_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PawmateApp());
}

/// Root widget for the Pawmate Flutter application.
class PawmateApp extends StatefulWidget {
  const PawmateApp({super.key});

  @override
  State<PawmateApp> createState() => _PawmateAppState();
}

class _PawmateAppState extends State<PawmateApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _appLinks = AppLinks();
  String? _lastOpenedInvite;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _linkSubscription = _appLinks.uriLinkStream.listen(_openInviteLink);
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _openInviteLink(Uri uri) {
    if (uri.scheme != 'pawmate' || uri.host != 'pair') return;
    if (uri.queryParameters['server'] == null ||
        uri.queryParameters['code'] == null ||
        _lastOpenedInvite == uri.toString()) {
      return;
    }
    _lastOpenedInvite = uri.toString();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigatorKey.currentState?.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => InviteeAcceptPage(inviteUri: uri),
        ),
      );
    });
  }

  /// Configures the app theme and starts the inviter onboarding flow.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Pawmate',
      theme: buildPawmateTheme(),
      home: const InviterSetupPage(),
    );
  }
}
