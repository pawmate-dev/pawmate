import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/layouts/handdrawn_scaffold.dart';
import 'widgets/invite_result_card.dart';
import 'widgets/pairing_error_note.dart';
import 'widgets/server_setup_card.dart';
import 'widgets/member_profile_editor.dart';
import 'pairing_api.dart';
import 'pairing_credentials.dart';
import 'paired_home_page.dart';
import '../../l10n/generated/app_localizations.dart';

class InviterSetupPage extends StatefulWidget {
  const InviterSetupPage({super.key});

  @override
  State<InviterSetupPage> createState() => _InviterSetupPageState();
}

class _InviterSetupPageState extends State<InviterSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _profileKey = GlobalKey<MemberProfileEditorState>();
  final _serverURLController = TextEditingController();
  final _api = PairingApi();
  final _credentials = PairingCredentials();
  PairingInvite? _invite;
  PairingStatus? _status;
  String? _errorMessage;
  bool _isLoading = false;

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
      final invite = await _api.createInvite(
        _serverURLController.text,
        profile: _profileKey.currentState!.profile!,
      );
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
            _errorMessage = AppLocalizations.of(
              context,
            )!.invitationCreatedStorageWarning;
          });
        }
      }
    } on PairingApiException catch (error) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(
          () => _errorMessage = error.message.startsWith('Use an HTTP')
              ? l10n.invalidServerAddress
              : error.message == 'invalid_profile'
              ? l10n.profileRejected
              : error.statusCode == null
              ? l10n.serverUnreachable
              : l10n.requestFailed,
        );
      }
    } on Object {
      if (mounted) {
        setState(
          () => _errorMessage = AppLocalizations.of(context)!.serverUnreachable,
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
    } on PairingApiException {
      if (mounted) {
        setState(
          () => _errorMessage = AppLocalizations.of(context)!.requestFailed,
        );
      }
    } on Object {
      if (mounted) {
        setState(
          () => _errorMessage = AppLocalizations.of(
            context,
          )!.serverUnreachableShort,
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.invitationCopied)),
      );
    }
  }

  /// Builds the inviter's server configuration and invitation screen.
  @override
  Widget build(BuildContext context) {
    final invite = _invite;
    final status = _status;
    return HanddrawnScaffold(
      title: AppLocalizations.of(context)!.invitePartner,
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            const SizedBox(height: 6),
            if (invite == null || !invite.expiresAt.isAfter(DateTime.now()))
              ServerSetupCard(
                formKey: _formKey,
                controller: _serverURLController,
                isLoading: _isLoading,
                onCreateInvite: () => _createInvite(),
                profileEditor: MemberProfileEditor(
                  key: _profileKey,
                  enabled: !_isLoading,
                ),
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
          ],
        ),
      ),
    );
  }
}
