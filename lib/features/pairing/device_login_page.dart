import 'package:flutter/material.dart';

import '../../design/components/handdrawn_button.dart';
import '../../design/components/handdrawn_card.dart';
import '../../design/layouts/handdrawn_scaffold.dart';
import '../../design/components/handdrawn_text_field.dart';
import '../../design/icons/access/access_doodle_icon.dart';
import '../../design/theme/colors.dart';
import '../../design/theme/spacing.dart';
import 'paired_home_page.dart';
import 'pairing_api.dart';
import 'pairing_credentials.dart';
import 'widgets/pairing_error_note.dart';
import '../../l10n/generated/app_localizations.dart';

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
  final _name = TextEditingController();
  final _api = PairingApi();
  final _credentials = PairingCredentials();
  bool _busy = false;
  bool _initializedName = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedName) {
      _name.text = AppLocalizations.of(context)!.myDeviceName;
      _initializedName = true;
    }
  }

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
          () => _error = switch (error.message) {
            'invalid_device_code' => AppLocalizations.of(
              context,
            )!.invalidDeviceCode,
            _ => AppLocalizations.of(context)!.requestFailed,
          },
        );
      }
    } on Object {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context)!.couldNotSignIn);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => HanddrawnScaffold(
    title: AppLocalizations.of(context)!.bringHome,
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
                  const Center(
                    child: AccessDoodleIcon(
                      symbol: AccessDoodle.addDevice,
                      color: PawmateColors.lavender,
                    ),
                  ),
                  const SizedBox(height: PawmateSpace.large),
                  Text(
                    AppLocalizations.of(context)!.signInAnotherDevice,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context)!.deviceSignInHelp,
                    style: const TextStyle(
                      color: PawmateColors.softBrown,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  HanddrawnTextField(
                    controller: _server,
                    labelText: AppLocalizations.of(context)!.serverUrl,
                    hintText: AppLocalizations.of(context)!.serverUrlHint,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? AppLocalizations.of(context)!.enterServerAddress
                        : null,
                  ),
                  const SizedBox(height: 12),
                  HanddrawnTextField(
                    controller: _code,
                    labelText: AppLocalizations.of(context)!.deviceLoginCode,
                    keyboardType: TextInputType.text,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? AppLocalizations.of(context)!.enterLoginCode
                        : null,
                  ),
                  const SizedBox(height: 12),
                  HanddrawnTextField(
                    controller: _name,
                    labelText: AppLocalizations.of(context)!.deviceName,
                    keyboardType: TextInputType.text,
                    validator: (value) =>
                        value == null ||
                            value.trim().isEmpty ||
                            value.trim().runes.length > 80
                        ? AppLocalizations.of(context)!.deviceNameLength
                        : null,
                  ),
                  const SizedBox(height: 20),
                  HanddrawnButton(
                    label: _busy
                        ? AppLocalizations.of(context)!.signingIn
                        : AppLocalizations.of(context)!.signIn,
                    icon: Icons.devices,
                    onPressed: _busy ? null : _signIn,
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: Text(AppLocalizations.of(context)!.back),
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
