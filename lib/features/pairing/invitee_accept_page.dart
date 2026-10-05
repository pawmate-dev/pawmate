import 'package:flutter/material.dart';

import '../../design/components/handdrawn_button.dart';
import '../../design/components/handdrawn_card.dart';
import '../../design/layouts/handdrawn_scaffold.dart';
import '../../design/theme/colors.dart';
import 'pairing_api.dart';
import 'pairing_credentials.dart';
import 'paired_home_page.dart';
import 'widgets/pairing_error_note.dart';
import 'widgets/member_profile_editor.dart';
import '../../l10n/generated/app_localizations.dart';

/// Lets the invitee review and accept a one-time link opened from another app.
class InviteeAcceptPage extends StatefulWidget {
  const InviteeAcceptPage({required this.inviteUri, super.key});

  final Uri inviteUri;

  @override
  State<InviteeAcceptPage> createState() => _InviteeAcceptPageState();
}

class _InviteeAcceptPageState extends State<InviteeAcceptPage> {
  final _formKey = GlobalKey<FormState>();
  final _profileKey = GlobalKey<MemberProfileEditorState>();
  final _api = PairingApi();
  final _credentials = PairingCredentials();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _acceptInvite() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = _profileKey.currentState!.profile!;
    final l10n = AppLocalizations.of(context)!;
    final serverURL = widget.inviteUri.queryParameters['server'];
    final code = widget.inviteUri.queryParameters['code'];
    if (serverURL == null || code == null || code.isEmpty) {
      setState(
        () =>
            _errorMessage = AppLocalizations.of(context)!.incompleteInvitation,
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = await _api.redeemInvite(serverURL, code, profile: profile);
      final token = result.inviteeToken;
      final recoveryCode = result.recoveryCode;
      final pairID = result.pairID;
      if (token == null || recoveryCode == null || pairID == null) {
        throw PairingApiException(l10n.incompleteCredentials);
      }
      var storageWarning = false;
      try {
        await _credentials.save(
          serverURL: serverURL,
          accessToken: token,
          recoveryCode: recoveryCode,
          pairID: pairID,
          role: 'invitee',
        );
      } on Object {
        storageWarning = true;
      }
      if (!mounted) return;
      final credentials = SavedPairingCredentials(
        serverURL: serverURL,
        accessToken: token,
        recoveryCode: recoveryCode,
        pairID: pairID,
        role: 'invitee',
      );
      Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(
          builder: (_) => PairedHomePage(
            credentials: credentials,
            session: PairingSession(
              pairID: pairID,
              role: 'invitee',
              status: 'paired',
              profile: profile,
            ),
            recoveryCodeToSave: recoveryCode,
            storageWarning: storageWarning,
          ),
        ),
        (_) => false,
      );
    } on PairingApiException catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage = switch (error.message) {
            'invalid_profile' => l10n.profileRejected,
            _ => l10n.requestFailed,
          },
        );
      }
    } on Object {
      if (mounted) {
        setState(
          () => _errorMessage = AppLocalizations.of(context)!.couldNotAccept,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final serverURL = widget.inviteUri.queryParameters['server'] ?? 'Unknown';
    return HanddrawnScaffold(
      title: AppLocalizations.of(context)!.joinHome,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            HanddrawnCard(
              color: const Color(0xFFF4F0FF),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    MemberProfileEditor(key: _profileKey, enabled: !_isLoading),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context)!.invited,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: PawmateColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.acceptOneTimeHelp,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: PawmateColors.softBrown,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.privateServer,
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
                    const SizedBox(height: 20),
                    HanddrawnButton(
                      onPressed: _isLoading ? null : _acceptInvite,
                      icon: Icons.favorite_border,
                      label: _isLoading
                          ? AppLocalizations.of(context)!.joining
                          : AppLocalizations.of(context)!.acceptInvitation,
                    ),
                  ],
                ),
              ),
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
