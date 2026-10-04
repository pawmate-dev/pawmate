import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design/components/handdrawn_button.dart';
import '../../../design/components/handdrawn_card.dart';
import '../pairing_api.dart';
import '../pairing_credentials.dart';
import '../pairing_session_gate.dart';
import 'pairing_error_note.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Lists the current member's devices and authorizes additional installations.
class DevicesCard extends StatefulWidget {
  const DevicesCard({required this.credentials, super.key});

  final SavedPairingCredentials credentials;

  @override
  State<DevicesCard> createState() => _DevicesCardState();
}

class _DevicesCardState extends State<DevicesCard> {
  final _api = PairingApi();
  List<PairingDevice>? _devices;
  DeviceLoginCode? _code;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  /// Applies a device operation, showing retryable failures and expired sessions.
  Future<void> _perform(Future<void> Function() operation) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
    } on PairingApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401) {
        Navigator.of(context).pushAndRemoveUntil<void>(
          MaterialPageRoute<void>(builder: (_) => const PairingSessionGate()),
          (_) => false,
        );
      } else {
        setState(() => _error = AppLocalizations.of(context)!.requestFailed);
      }
    } on Object {
      if (mounted) {
        setState(
          () => _error = AppLocalizations.of(context)!.couldNotReachRetry,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Refreshes the list without replacing any member credentials.
  Future<void> _refresh() => _perform(() async {
    final saved = widget.credentials;
    final devices = await _api.getDevices(saved.serverURL, saved.accessToken);
    if (mounted) setState(() => _devices = devices);
  });

  /// Creates a code for this member, invalidating this device's previous code.
  Future<void> _addDevice() => _perform(() async {
    final saved = widget.credentials;
    final code = await _api.createDeviceLoginCode(
      saved.serverURL,
      saved.accessToken,
    );
    if (mounted) setState(() => _code = code);
  });

  /// Confirms and removes a remote device without signing out this installation.
  Future<void> _removeDevice(PairingDevice device) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.signOutDeviceTitle(device.name)),
        content: Text(l10n.signOutDeviceHelp),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.signOutDevice),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _perform(() async {
      final saved = widget.credentials;
      await _api.revokeDevice(saved.serverURL, saved.accessToken, device.id);
      final devices = await _api.getDevices(saved.serverURL, saved.accessToken);
      if (mounted) setState(() => _devices = devices);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final code = _code;
    return HanddrawnCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.myDevices, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(l10n.devicesHelp),
          if (_devices != null) ...[
            for (final device in _devices!)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      device.current
                          ? l10n.thisDevice
                          : l10n.addedDate(
                              MaterialLocalizations.of(
                                context,
                              ).formatShortDate(device.createdAt.toLocal()),
                            ),
                    ),
                    if (!device.current)
                      TextButton.icon(
                        onPressed: _busy ? null : () => _removeDevice(device),
                        icon: const Icon(Icons.logout),
                        label: Text(l10n.signOutDevice),
                      ),
                  ],
                ),
              ),
          ],
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),
          TextButton.icon(
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.refreshDevices),
          ),
          HanddrawnButton(
            label: l10n.addDeviceAction,
            icon: Icons.add_to_queue,
            onPressed: _busy ? null : _addDevice,
          ),
          if (code != null) ...[
            const SizedBox(height: 16),
            Text(l10n.newDeviceCodeHelp),
            const SizedBox(height: 8),
            SelectableText(
              code.code,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            Text(
              l10n.singleUseExpires(
                MaterialLocalizations.of(
                  context,
                ).formatMediumDate(code.expiresAt.toLocal()),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code.code));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.deviceCodeCopied)),
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: Text(l10n.copyLoginCode),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            PairingErrorNote(message: _error!),
          ],
        ],
      ),
    );
  }
}
