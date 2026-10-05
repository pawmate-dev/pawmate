import 'package:flutter/material.dart';

import '../../design/layouts/handdrawn_scaffold.dart';
import '../../l10n/generated/app_localizations.dart';
import '../chat/chat_api.dart';
import '../chat/storage/chat_store.dart';
import 'inviter_setup_page.dart';
import 'login_methods_page.dart';
import 'paired_home_page.dart';
import 'pairing_api.dart';
import 'pairing_credentials.dart';

/// Restores local identity without making startup depend on a network request.
class PairingSessionGate extends StatefulWidget {
  const PairingSessionGate({
    super.key,
    this.credentials,
    this.chatApi,
    this.store,
  });
  final PairingCredentials? credentials;
  final ChatApi? chatApi;
  final Future<ChatStore>? store;

  @override
  State<PairingSessionGate> createState() => _PairingSessionGateState();
}

class _PairingSessionGateState extends State<PairingSessionGate> {
  SavedPairingCredentials? _saved;
  bool _restoring = true;
  bool _storageError = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  /// A missing or unreadable local credential never becomes a guessed identity.
  Future<void> _restore() async {
    try {
      final saved = await (widget.credentials ?? PairingCredentials()).read();
      if (mounted) {
        setState(() {
          _saved = saved;
          _storageError = false;
        });
      }
    } on Object {
      if (mounted) setState(() => _storageError = true);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring) {
      return const HanddrawnScaffold(title: null, body: SizedBox.shrink());
    }
    final saved = _saved;
    if (saved == null) {
      return Column(
        children: [
          if (_storageError)
            MaterialBanner(
              content: Text(AppLocalizations.of(context)!.savedAccessError),
              actions: [
                TextButton(
                  onPressed: _restore,
                  child: Text(AppLocalizations.of(context)!.retry),
                ),
              ],
            ),
          const Expanded(child: LoginMethodsPage()),
        ],
      );
    }
    if (saved.pairID.isEmpty) return const InviterSetupPage();
    return PairedHomePage(
      credentials: saved,
      session: PairingSession(
        role: saved.role,
        status: 'paired',
        pairID: saved.pairID,
      ),
      chatApi: widget.chatApi,
      chatStore: widget.store,
    );
  }
}
