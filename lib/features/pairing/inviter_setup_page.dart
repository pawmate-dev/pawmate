import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/handdrawn_scaffold.dart';
import '../../design/pawmate_theme.dart';
import 'widgets/invite_result_card.dart';
import 'widgets/pairing_error_note.dart';
import 'widgets/pairing_header.dart';
import 'widgets/pairing_recovery_card.dart';
import 'widgets/recovery_code_note.dart';
import 'widgets/server_setup_card.dart';
import 'pairing_api.dart';
import 'pairing_credentials.dart';
import 'paired_home_page.dart';

class InviterSetupPage extends StatefulWidget {
  const InviterSetupPage({super.key});

  @override
  State<InviterSetupPage> createState() => _InviterSetupPageState();
}

class _InviterSetupPageState extends State<InviterSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _serverURLController = TextEditingController();
  final _recoveryServerController = TextEditingController();
  final _recoveryCodeController = TextEditingController();
  final _api = PairingApi();
  final _credentials = PairingCredentials();
  PairingInvite? _invite;
  PairingStatus? _status;
  String? _errorMessage;
  bool _isLoading = false;
  String? _recoveredCode;
  String? _recoveredRole;

  @override
  void initState() {
    super.initState();
    _restoreSavedInvite();
  }

  Future<void> _restoreSavedInvite() async {
    try {
      final credentials = await _credentials.read();
      if (!mounted || credentials == null || credentials.role != 'inviter') {
        return;
      }
      _serverURLController.text = credentials.serverURL;
      final inviteURL = credentials.inviteURL;
      final expiresAt = credentials.expiresAt;
      if (inviteURL != null && expiresAt != null) {
        setState(() {
          _invite = PairingInvite(
            inviteURL: inviteURL,
            inviterToken: credentials.accessToken,
            recoveryCode: credentials.recoveryCode,
            expiresAt: expiresAt,
          );
        });
        await _refreshStatus();
      }
    } on Object {
      // A damaged local credential record must not block server setup.
    }
  }

  /// Releases controllers and the HTTP client owned by this page.
  @override
  void dispose() {
    _serverURLController.dispose();
    _recoveryServerController.dispose();
    _recoveryCodeController.dispose();
    _api.close();
    super.dispose();
  }

  /// Sends the configured server URL and displays the returned invitation.
  Future<void> _createInvite() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _errorMessage = null;
      _isLoading = true;
      _invite = null;
      _status = null;
    });
    try {
      final invite = await _api.createInvite(_serverURLController.text);
      if (!mounted) return;
      setState(() => _invite = invite);
      try {
        await _credentials.save(
          serverURL: _serverURLController.text.trim(),
          accessToken: invite.inviterToken,
          recoveryCode: invite.recoveryCode,
          pairID: '',
          role: 'inviter',
          inviteURL: invite.inviteURL,
          expiresAt: invite.expiresAt,
        );
      } on Object {
        if (mounted) {
          setState(() {
            _errorMessage =
                'Invitation created. Save the recovery code below; this device could not store it securely.';
          });
        }
      }
    } on PairingApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on Object {
      if (mounted) {
        setState(() => _errorMessage = 'Could not reach the Pawmate server.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Restores this member's access after reinstall and rotates the recovery code.
  Future<void> _recoverAccess() async {
    setState(() {
      _errorMessage = null;
      _recoveredCode = null;
      _recoveredRole = null;
      _isLoading = true;
    });
    try {
      final credentials = await _api.recover(
        _recoveryServerController.text,
        _recoveryCodeController.text,
      );
      await _credentials.save(
        serverURL: _recoveryServerController.text.trim(),
        accessToken: credentials.accessToken,
        recoveryCode: credentials.recoveryCode,
        pairID: credentials.pairID,
        role: credentials.role,
      );
      if (mounted) {
        setState(() {
          _recoveredCode = credentials.recoveryCode;
          _recoveredRole = credentials.role;
        });
      }
    } on PairingApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on Object {
      if (mounted) {
        setState(
          () => _errorMessage = 'Could not restore access to this home.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Refreshes the invitation state shown to the inviter.
  Future<void> _refreshStatus() async {
    final invite = _invite;
    if (invite == null) return;
    setState(() => _isLoading = true);
    try {
      final status = await _api.getStatus(
        _serverURLController.text,
        invite.inviterToken,
      );
      if (status.status == 'paired' && status.pairID != null) {
        var storageWarning = false;
        try {
          await _credentials.save(
            serverURL: _serverURLController.text.trim(),
            accessToken: invite.inviterToken,
            recoveryCode: invite.recoveryCode,
            pairID: status.pairID!,
            role: 'inviter',
            inviteURL: invite.inviteURL,
            expiresAt: invite.expiresAt,
          );
        } on Object {
          storageWarning = true;
        }
        if (!mounted) return;
        final credentials = SavedPairingCredentials(
          serverURL: _serverURLController.text.trim(),
          accessToken: invite.inviterToken,
          recoveryCode: invite.recoveryCode,
          pairID: status.pairID!,
          role: 'inviter',
          inviteURL: invite.inviteURL,
          expiresAt: invite.expiresAt,
        );
        Navigator.of(context).pushAndRemoveUntil<void>(
          MaterialPageRoute<void>(
            builder: (_) => PairedHomePage(
              credentials: credentials,
              session: PairingSession(
                pairID: status.pairID,
                role: 'inviter',
                status: 'paired',
              ),
              recoveryCodeToSave: storageWarning ? invite.recoveryCode : null,
              storageWarning: storageWarning,
            ),
          ),
          (_) => false,
        );
        return;
      }
      if (mounted) setState(() => _status = status);
    } on PairingApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on Object {
      if (mounted) {
        setState(() => _errorMessage = 'Could not reach the server.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Copies the bearer invitation link to the platform clipboard.
  Future<void> _copyInvite() async {
    final invite = _invite;
    if (invite == null) return;
    await Clipboard.setData(ClipboardData(text: invite.inviteURL));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invitation link copied')));
    }
  }

  /// Builds the inviter's server configuration and invitation screen.
  @override
  Widget build(BuildContext context) {
    final invite = _invite;
    final status = _status;
    return HanddrawnScaffold(
      title: 'Invite your partner',
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            const PairingHeader(),
            const SizedBox(height: 20),
            ServerSetupCard(
              formKey: _formKey,
              controller: _serverURLController,
              isLoading: _isLoading,
              onCreateInvite: () => _createInvite(),
            ),
            const SizedBox(height: 18),
            PairingRecoveryCard(
              serverController: _recoveryServerController,
              codeController: _recoveryCodeController,
              isLoading: _isLoading,
              onRecover: () => _recoverAccess(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 18),
              PairingErrorNote(message: _errorMessage!),
            ],
            if (invite != null) ...[
              const SizedBox(height: 22),
              InviteResultCard(
                invite: invite,
                recoveryCode: invite.recoveryCode,
                status: status,
                isLoading: _isLoading,
                onCopy: () => _copyInvite(),
                onRefresh: () => _refreshStatus(),
              ),
            ],
            if (_recoveredCode != null) ...[
              const SizedBox(height: 18),
              if (_recoveredRole != null)
                Text(
                  'Access restored for the ${_recoveredRole!} member.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: PawmateColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 8),
              RecoveryCodeNote(recoveryCode: _recoveredCode!),
            ],
          ],
        ),
      ),
    );
  }
}
