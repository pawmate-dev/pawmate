import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pairing_api.dart';

class InviterSetupPage extends StatefulWidget {
  const InviterSetupPage({super.key});

  @override
  State<InviterSetupPage> createState() => _InviterSetupPageState();
}

class _InviterSetupPageState extends State<InviterSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _serverURLController = TextEditingController();
  final _api = PairingApi();
  PairingInvite? _invite;
  PairingStatus? _status;
  String? _errorMessage;
  bool _isLoading = false;

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
      _status = null;
    });
    try {
      final invite = await _api.createInvite(_serverURLController.text);
      if (!mounted) return;
      setState(() => _invite = invite);
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
      if (mounted) setState(() => _status = status);
    } on PairingApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on Object {
      if (mounted)
        setState(() => _errorMessage = 'Could not reach the server.');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Invite your partner')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Start your little home',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose the private server for your home, then create one invitation for your partner.',
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _serverURLController,
                autocorrect: false,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Server URL or domain',
                  hintText: 'https://pawmate.example.com',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter your server URL.';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isLoading ? null : _createInvite,
              icon: const Icon(Icons.favorite_border),
              label: Text(_isLoading ? 'Working…' : 'Create invitation'),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (invite != null) ...[
              const SizedBox(height: 28),
              const Text(
                'Share this one-time invitation link',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SelectableText(invite.inviteURL),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _copyInvite,
                icon: const Icon(Icons.copy),
                label: const Text('Copy invitation link'),
              ),
              const SizedBox(height: 8),
              Text(
                'Expires ${invite.expiresAt.toLocal()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _refreshStatus,
                icon: const Icon(Icons.refresh),
                label: const Text('Check pairing status'),
              ),
              if (status != null) ...[
                const SizedBox(height: 12),
                Text(
                  status.status == 'paired'
                      ? 'Your partner is paired!'
                      : 'Waiting for your partner to accept…',
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
