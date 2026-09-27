import 'package:flutter/material.dart';

import '../../design/handdrawn_button.dart';
import '../../design/handdrawn_card.dart';
import '../../design/handdrawn_scaffold.dart';
import '../../design/pawmate_theme.dart';
import 'pairing_api.dart';
import 'pairing_credentials.dart';
import 'widgets/pairing_error_note.dart';
import 'widgets/recovery_code_note.dart';

/// Lets the invitee review and accept a one-time link opened from another app.
class InviteeAcceptPage extends StatefulWidget {
  const InviteeAcceptPage({required this.inviteUri, super.key});

  final Uri inviteUri;

  @override
  State<InviteeAcceptPage> createState() => _InviteeAcceptPageState();
}

class _InviteeAcceptPageState extends State<InviteeAcceptPage> {
  final _api = PairingApi();
  final _credentials = PairingCredentials();
  bool _isLoading = false;
  String? _errorMessage;
  String? _recoveryCode;

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _acceptInvite() async {
    final serverURL = widget.inviteUri.queryParameters['server'];
    final code = widget.inviteUri.queryParameters['code'];
    if (serverURL == null || code == null || code.isEmpty) {
      setState(() => _errorMessage = 'This invitation link is incomplete.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = await _api.redeemInvite(serverURL, code);
      final token = result.inviteeToken;
      final recoveryCode = result.recoveryCode;
      final pairID = result.pairID;
      if (token == null || recoveryCode == null || pairID == null) {
        throw const PairingApiException(
          'The server did not return complete pairing credentials.',
        );
      }
      if (mounted) setState(() => _recoveryCode = recoveryCode);
      try {
        await _credentials.save(
          serverURL: serverURL,
          accessToken: token,
          recoveryCode: recoveryCode,
          pairID: pairID,
          role: 'invitee',
        );
      } on Object {
        if (mounted) {
          setState(() {
            _errorMessage =
                'You are paired, but this device could not store access securely. Keep the recovery code below safe.';
          });
        }
      }
    } on PairingApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on Object {
      if (mounted) {
        setState(() => _errorMessage = 'Could not accept this invitation.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final serverURL = widget.inviteUri.queryParameters['server'] ?? 'Unknown';
    final accepted = _recoveryCode != null;
    return HanddrawnScaffold(
      title: 'Join your little home',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            HanddrawnCard(
              color: const Color(0xFFF4F0FF),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.mail_outline,
                    size: 32,
                    color: PawmateColors.lavender,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    accepted ? 'You are home!' : 'You have been invited',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: PawmateColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    accepted
                        ? 'Your place in this private home is now connected.'
                        : 'Accepting this one-time invitation will pair your device with your partner.',
                    style: const TextStyle(
                      color: PawmateColors.softBrown,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Private server',
                    style: TextStyle(
                      color: PawmateColors.softBrown,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    serverURL,
                    style: const TextStyle(
                      color: PawmateColors.ink,
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (!accepted) ...[
                    const SizedBox(height: 20),
                    HanddrawnButton(
                      onPressed: _isLoading ? null : _acceptInvite,
                      icon: Icons.favorite_border,
                      label: _isLoading ? 'Joining…' : 'Accept invitation',
                    ),
                  ],
                ],
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 18),
              PairingErrorNote(message: _errorMessage!),
            ],
            if (_recoveryCode case final code?) ...[
              const SizedBox(height: 18),
              RecoveryCodeNote(recoveryCode: code),
            ],
          ],
        ),
      ),
    );
  }
}
