import 'package:flutter/material.dart';

import '../../design/handdrawn_card.dart';
import '../../design/handdrawn_scaffold.dart';
import '../../design/pawmate_theme.dart';
import 'pairing_api.dart';
import 'pairing_credentials.dart';
import 'widgets/pairing_error_note.dart';
import 'widgets/recovery_code_note.dart';
import 'widgets/devices_card.dart';
import '../chat/chat_api.dart';
import '../chat/chat_controller.dart';
import '../chat/chat_page.dart';
import 'pairing_session_gate.dart';

/// Opens the couple space on chat, retaining drafts and scroll state between tabs.
class PairedHomePage extends StatefulWidget {
  const PairedHomePage({
    required this.credentials,
    required this.session,
    super.key,
    this.recoveryCodeToSave,
    this.storageWarning = false,
    this.chatApi,
  });

  final SavedPairingCredentials credentials;
  final PairingSession session;
  final String? recoveryCodeToSave;
  final bool storageWarning;
  final ChatApi? chatApi;

  @override
  State<PairedHomePage> createState() => _PairedHomePageState();
}

class _PairedHomePageState extends State<PairedHomePage>
    with WidgetsBindingObserver {
  late final ChatController _chat;
  int _tab = 0;
  int _lastUnread = 0;
  bool _loaded = false;
  bool _redirecting = false;
  bool _homeNotice = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chat = ChatController(widget.chatApi ?? ChatApi(widget.credentials))
      ..addListener(_changed);
    _chat.setForeground(
      WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    );
    _chat.start();
  }

  /// Pauses polling and read receipts when the application leaves the foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _chat.setForeground(state == AppLifecycleState.resumed);

  /// Shows content-free unread reminders and redirects revoked device sessions.
  void _changed() {
    if (!mounted) return;
    if (_chat.unauthorized && !_redirecting) {
      _redirecting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil<void>(
          MaterialPageRoute<void>(builder: (_) => const PairingSessionGate()),
          (_) => false,
        );
      });
    }
    if (_loaded &&
        _chat.foreground &&
        _tab != 0 &&
        _chat.unreadCount > _lastUnread) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${_chat.unreadCount} unread messages from your partner',
            ),
            action: SnackBarAction(
              label: 'Open chat',
              onPressed: () => _selectTab(0),
            ),
          ),
        );
    }
    _lastUnread = _chat.unreadCount;
    _loaded = _chat.loaded;
    setState(() {});
  }

  /// Changes the active tab without acknowledging unseen messages.
  void _selectTab(int index) {
    _chat.setChatVisible(index == 0);
    setState(() {
      _tab = index;
      if (index == 2) _homeNotice = false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chat.removeListener(_changed);
    _chat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HanddrawnScaffold(
    title: ['Our conversation', 'Play corner', 'Our little home'][_tab],
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: _selectTab,
      destinations: [
        NavigationDestination(
          icon: Badge(
            isLabelVisible: _chat.unreadCount > 0,
            label: Text(
              _chat.unreadCount > 99 ? '99+' : '${_chat.unreadCount}',
            ),
            child: const Icon(Icons.chat_bubble_outline),
          ),
          label: 'Chat',
          tooltip: 'Chat, ${_chat.unreadCount} unread messages',
        ),
        const NavigationDestination(
          icon: Icon(Icons.sports_esports_outlined),
          label: 'Play',
        ),
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          label: 'Home',
        ),
      ],
    ),
    body: Column(
      children: [
        if (_homeNotice &&
            (widget.recoveryCodeToSave != null || widget.storageWarning))
          MaterialBanner(
            content: Text(
              widget.storageWarning
                  ? 'This device could not save its login. Open Home for reconnect instructions.'
                  : 'Save your recovery code in Home before leaving.',
            ),
            actions: [
              TextButton(
                onPressed: () => _selectTab(2),
                child: const Text('View Home'),
              ),
            ],
          ),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: [
              ChatPage(controller: _chat, active: _tab == 0),
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: HanddrawnCard(
                    child: Text(
                      'A little corner for playing together.\nGames will arrive here later.',
                    ),
                  ),
                ),
              ),
              _HomeDetails(
                credentials: widget.credentials,
                session: widget.session,
                recoveryCodeToSave: widget.recoveryCodeToSave,
                storageWarning: widget.storageWarning,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Keeps pairing details, device management and recovery notes in the Home tab.
class _HomeDetails extends StatelessWidget {
  const _HomeDetails({
    required this.credentials,
    required this.session,
    this.recoveryCodeToSave,
    this.storageWarning = false,
  });

  final SavedPairingCredentials credentials;
  final PairingSession session;
  final String? recoveryCodeToSave;
  final bool storageWarning;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          HanddrawnCard(
            color: const Color(0xFFF4F0FF),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.home_rounded,
                  size: 36,
                  color: PawmateColors.rose,
                ),
                const SizedBox(height: 12),
                Text(
                  'You are home together',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: PawmateColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This device is connected as the ${session.role}.',
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
                  credentials.serverURL,
                  style: const TextStyle(
                    color: PawmateColors.ink,
                    fontFamily: 'monospace',
                  ),
                ),
                if (session.pairID != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Home ID: ${session.pairID}',
                    style: const TextStyle(
                      color: PawmateColors.softBrown,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (storageWarning) ...[
            const SizedBox(height: 18),
            PairingErrorNote(
              message: recoveryCodeToSave != null
                  ? 'This device could not securely save its login. Keep the recovery code below in case the app closes.'
                  : 'This device could not securely save its login. If the app closes, generate a new login code on another signed-in device to reconnect.',
            ),
          ],
          if (recoveryCodeToSave != null) ...[
            const SizedBox(height: 18),
            RecoveryCodeNote(recoveryCode: recoveryCodeToSave!),
          ],
          const SizedBox(height: 18),
          DevicesCard(credentials: credentials),
        ],
      ),
    );
  }
}
