import 'package:flutter/material.dart';

import '../../design/handdrawn_card.dart';
import '../../design/handdrawn_scaffold.dart';
import '../../design/pawmate_theme.dart';
import 'pairing_api.dart';
import 'pairing_credentials.dart';
import 'paired_home_page.dart';
import 'widgets/pairing_error_note.dart';
import 'widgets/pairing_recovery_card.dart';
import 'device_login_page.dart';

/// Restores an invalid or reinstalled member session with its recovery code.
class PairingRecoveryPage extends StatefulWidget {
  const PairingRecoveryPage({super.key, this.initialServerURL = ''});

  final String initialServerURL;

  @override
  State<PairingRecoveryPage> createState() => _PairingRecoveryPageState();
}

class _PairingRecoveryPageState extends State<PairingRecoveryPage> {
  late final TextEditingController _serverController;
  final _codeController = TextEditingController();
  final _api = PairingApi();
  final _credentials = PairingCredentials();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _serverController = TextEditingController(text: widget.initialServerURL);
  }

  @override
  void dispose() {
    _serverController.dispose();
    _codeController.dispose();
    _api.close();
    super.dispose();
  }

  Future<void> _recover() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = await _api.recover(
        _serverController.text,
        _codeController.text,
      );
      final saved = SavedPairingCredentials(
        serverURL: _serverController.text.trim(),
        accessToken: result.accessToken,
        recoveryCode: result.recoveryCode,
        pairID: result.pairID,
        role: result.role,
      );
      var storageWarning = false;
      try {
        await _credentials.save(
          serverURL: saved.serverURL,
          accessToken: saved.accessToken,
          recoveryCode: saved.recoveryCode,
          pairID: saved.pairID,
          role: saved.role,
        );
      } on Object {
        storageWarning = true;
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(
          builder: (_) => PairedHomePage(
            credentials: saved,
            session: PairingSession(
              pairID: result.pairID,
              role: result.role,
              status: 'paired',
            ),
            recoveryCodeToSave: result.recoveryCode,
            storageWarning: storageWarning,
          ),
        ),
        (_) => false,
      );
    } on PairingApiException catch (error) {
      if (mounted) setState(() => _errorMessage = _userMessage(error));
    } on Object {
      if (mounted) {
        setState(
          () => _errorMessage = 'Could not restore this home. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _userMessage(PairingApiException error) {
    return switch (error.message) {
      'invalid_recovery_code' => 'That recovery code is not valid anymore.',
      'not_paired' => 'This server does not have a completed couple pairing.',
      _ => error.message,
    };
  }

  @override
  Widget build(BuildContext context) {
    return HanddrawnScaffold(
      title: 'Restore your home',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            HanddrawnCard(
              color: const Color(0xFFFFF3CF),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.key_outlined, color: PawmateColors.ink),
                  const SizedBox(height: 10),
                  Text(
                    'Let’s reconnect you',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: PawmateColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'This device needs a new login. If another device is still signed in, use its device login code. Recovery is for lost access and signs out all your other devices.',
                    style: TextStyle(
                      color: PawmateColors.softBrown,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            TextButton.icon(
              onPressed: _isLoading
                  ? null
                  : () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const DeviceLoginPage(),
                      ),
                    ),
              icon: const Icon(Icons.devices),
              label: const Text('Sign in with a device login code'),
            ),
            const SizedBox(height: 18),
            PairingRecoveryCard(
              serverController: _serverController,
              codeController: _codeController,
              isLoading: _isLoading,
              onRecover: _recover,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 18),
              PairingErrorNote(message: _errorMessage!),
            ],
          ],
        ),
      ),
    );
  }
}
