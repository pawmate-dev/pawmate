import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design/handdrawn_button.dart';
import '../../../design/handdrawn_card.dart';
import '../pairing_api.dart';
import '../pairing_credentials.dart';
import '../pairing_session_gate.dart';
import 'pairing_error_note.dart';

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
        setState(() => _error = error.message);
      }
    } on Object {
      if (mounted) {
        setState(() => _error = 'Could not reach your server. Try again.');
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sign out ${device.name}?'),
        content: const Text(
          'This device will need a new login code to reconnect. Your other devices will stay signed in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out device'),
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
    final code = _code;
    return HanddrawnCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My devices', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Keep your phone, tablet and computer connected to the same home. Only your own devices appear here.',
          ),
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
                          ? 'This device'
                          : 'Added ${device.createdAt.toLocal().toString().split(' ').first}',
                    ),
                    if (!device.current)
                      TextButton.icon(
                        onPressed: _busy ? null : () => _removeDevice(device),
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign out device'),
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
            label: const Text('Refresh devices'),
          ),
          HanddrawnButton(
            label: 'Add a device',
            icon: Icons.add_to_queue,
            onPressed: _busy ? null : _addDevice,
          ),
          if (code != null) ...[
            const SizedBox(height: 16),
            const Text(
              'On your new device, choose Sign in on another device. Use the server address above and this code. Keep it private: it grants access as you.',
            ),
            const SizedBox(height: 8),
            SelectableText(
              code.code,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            Text('Single use · Expires ${code.expiresAt.toLocal()}'),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code.code));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Device login code copied')),
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy login code'),
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
