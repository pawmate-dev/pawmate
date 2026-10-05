import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'design/theme/pawmate_theme.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/locale_controller.dart';
import 'features/pairing/invitee_accept_page.dart';
import 'features/pairing/invitation_link.dart';
import 'features/pairing/pairing_session_gate.dart';

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
  final _localeController = LocaleController();
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _appLinks = AppLinks();
  String? _lastOpenedInvite;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _localeController.addListener(_localeChanged);
    _localeController.restore();
    _linkSubscription = _appLinks.uriLinkStream.listen(_openInviteLink);
  }

  void _localeChanged() => setState(() {});

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _localeController
      ..removeListener(_localeChanged)
      ..dispose();
    super.dispose();
  }

  void _openInviteLink(Uri uri) {
    try {
      InvitationLink.parse(uri.toString());
    } on FormatException {
      return;
    }
    if (_lastOpenedInvite == uri.toString()) {
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

  /// Configures the app theme and restores a session or offers access methods.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Pawmate',
      theme: buildPawmateTheme(),
      locale: _localeController.locale,
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: LocaleControllerScope(
        notifier: _localeController,
        child: const PairingSessionGate(),
      ),
    );
  }
}
