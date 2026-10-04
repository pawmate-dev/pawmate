import 'package:flutter/material.dart';

import '../../design/handdrawn_button.dart';
import '../../design/handdrawn_card.dart';
import '../../design/handdrawn_scaffold.dart';
import '../../design/handdrawn_text_field.dart';
import 'paired_home_page.dart';
import 'pairing_api.dart';
import 'pairing_credentials.dart';
import 'widgets/pairing_error_note.dart';

/// Adds this installation to an existing member using a one-time login code.
class DeviceLoginPage extends StatefulWidget {
  const DeviceLoginPage({super.key});

  @override
  State<DeviceLoginPage> createState() => _DeviceLoginPageState();
}

class _DeviceLoginPageState extends State<DeviceLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _server = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController(text: PairingApi.defaultDeviceName);
  final _api = PairingApi();
  final _credentials = PairingCredentials();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _server.dispose();
    _code.dispose();
    _name.dispose();
    _api.close();
    super.dispose();
  }

  /// Consumes a login code and saves only this device's independent credentials.
  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _api.redeemDeviceLoginCode(
        _server.text,
        _code.text,
        _name.text,
      );
      final saved = SavedPairingCredentials(
        serverURL: _server.text.trim(),
        accessToken: result.accessToken,
        // A device login grants a session, never the member's recovery secret.
        recoveryCode: '',
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
              role: saved.role,
              status: 'paired',
              pairID: saved.pairID,
            ),
            storageWarning: storageWarning,
          ),
        ),
        (_) => false,
      );
    } on PairingApiException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.message == 'invalid_device_code'
              ? 'This login code expired or was already used. Generate a new one on your signed-in device.'
              : error.message,
        );
      }
    } on Object {
      if (mounted) {
        setState(
          () => _error =
              'Could not sign in. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => HanddrawnScaffold(
    title: 'Bring your home along',
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          HanddrawnCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sign in on another device',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'On your signed-in phone, tablet or computer, open My devices and choose Add a device. Enter its server address and login code here. Your other devices will stay signed in.',
                  ),
                  const SizedBox(height: 20),
                  HanddrawnTextField(
                    controller: _server,
                    labelText: 'Server URL',
                    hintText: 'https://pawmate.example.com',
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter your server address.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  HanddrawnTextField(
                    controller: _code,
                    labelText: 'Device login code',
                    keyboardType: TextInputType.text,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter the login code.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  HanddrawnTextField(
                    controller: _name,
                    labelText: 'Device name',
                    keyboardType: TextInputType.text,
                    validator: (value) =>
                        value == null ||
                            value.trim().isEmpty ||
                            value.trim().runes.length > 80
                        ? 'Use a name between 1 and 80 characters.'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  HanddrawnButton(
                    label: _busy ? 'Signing in…' : 'Sign in',
                    icon: Icons.devices,
                    onPressed: _busy ? null : _signIn,
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: const Text('Back'),
                  ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            PairingErrorNote(message: _error!),
          ],
        ],
      ),
    ),
  );
}
