import 'package:flutter/material.dart';

import '../../design/components/handdrawn_button.dart';
import '../../design/components/handdrawn_card.dart';
import '../../design/layouts/handdrawn_scaffold.dart';
import '../../design/theme/colors.dart';
import 'inviter_setup_page.dart';
import 'login_methods_page.dart';
import 'paired_home_page.dart';
import 'pairing_api.dart';
import 'pairing_credentials.dart';
import 'pairing_recovery_page.dart';
import '../../l10n/generated/app_localizations.dart';

/// Loads local credentials and routes to onboarding, recovery, or the home.
class PairingSessionGate extends StatefulWidget {
  const PairingSessionGate({super.key});

  @override
  State<PairingSessionGate> createState() => _PairingSessionGateState();
}

enum _GateView { loading, setup, invitation, recovery, home, error }

class _PairingSessionGateState extends State<PairingSessionGate> {
  final _api = PairingApi();
  final _credentials = PairingCredentials();
  _GateView _view = _GateView.loading;
  SavedPairingCredentials? _saved;
  PairingSession? _session;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    setState(() {
      _view = _GateView.loading;
      _errorMessage = null;
    });
    try {
      final credentials = await _credentials.read();
      if (!mounted) return;
      if (credentials == null) {
        setState(() => _view = _GateView.setup);
        return;
      }
      _saved = credentials;

      final session = await _api.validateSession(
        credentials.serverURL,
        credentials.accessToken,
      );
      if (!mounted) return;
      if (session.status == 'paired' && session.pairID != null) {
        final saved = SavedPairingCredentials(
          serverURL: credentials.serverURL,
          accessToken: credentials.accessToken,
          recoveryCode: credentials.recoveryCode,
          pairID: session.pairID!,
          role: session.role,
          inviteURL: credentials.inviteURL,
          expiresAt: credentials.expiresAt,
        );
        _saved = saved;
        _session = session;
        try {
          await _credentials.save(
            serverURL: saved.serverURL,
            accessToken: saved.accessToken,
            recoveryCode: saved.recoveryCode,
            pairID: saved.pairID,
            role: saved.role,
            inviteURL: saved.inviteURL,
            expiresAt: saved.expiresAt,
          );
        } on Object {
          // The authenticated in-memory session can still open the home.
        }
        if (mounted) setState(() => _view = _GateView.home);
      } else if (session.status == 'pending' && session.role == 'inviter') {
        setState(() => _view = _GateView.invitation);
      } else {
        setState(() => _view = _GateView.recovery);
      }
    } on PairingApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401) {
        setState(() => _view = _GateView.recovery);
      } else {
        setState(() {
          _errorMessage = _messageFor(error);
          _view = _GateView.error;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _errorMessage = AppLocalizations.of(context)!.savedAccessError;
          _view = _GateView.error;
        });
      }
    }
  }

  String _messageFor(PairingApiException error) {
    if (error.statusCode == null) {
      return AppLocalizations.of(context)!.serverAccessError;
    }
    return AppLocalizations.of(context)!.serverAccessError;
  }

  @override
  Widget build(BuildContext context) {
    return switch (_view) {
      _GateView.loading => const _SessionLoadingPage(),
      _GateView.setup => const LoginMethodsPage(),
      _GateView.invitation => const InviterSetupPage(),
      _GateView.recovery => PairingRecoveryPage(
        initialServerURL: _saved?.serverURL ?? '',
      ),
      _GateView.home => PairedHomePage(
        credentials: _saved!,
        session: _session!,
      ),
      _GateView.error => _SessionErrorPage(
        message:
            _errorMessage ?? AppLocalizations.of(context)!.sessionRestoreError,
        onRetry: _restoreSession,
        onSetup: () => setState(() => _view = _GateView.setup),
      ),
    };
  }
}

class _SessionLoadingPage extends StatelessWidget {
  const _SessionLoadingPage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HanddrawnScaffold(
      title: l10n.openingHome,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: PawmateColors.lavender),
            SizedBox(height: 16),
            Text(l10n.checkingSavedAccess),
          ],
        ),
      ),
    );
  }
}

class _SessionErrorPage extends StatelessWidget {
  const _SessionErrorPage({
    required this.message,
    required this.onRetry,
    required this.onSetup,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    return HanddrawnScaffold(
      title: AppLocalizations.of(context)!.findingHome,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HanddrawnCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      color: PawmateColors.softBrown,
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: PawmateColors.ink,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              HanddrawnButton(
                label: AppLocalizations.of(context)!.tryAgain,
                icon: Icons.refresh,
                onPressed: onRetry,
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: onSetup,
                child: Text(AppLocalizations.of(context)!.chooseSignInMethod),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
