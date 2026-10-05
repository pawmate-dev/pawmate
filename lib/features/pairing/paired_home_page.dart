import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/components/handdrawn_card.dart';
import '../../design/components/crayon_navigation_bar.dart';
import '../../design/icons/navigation/navigation_doodle_icon.dart';
import '../../design/components/couple_avatar.dart';
import '../../design/layouts/handdrawn_scaffold.dart';
import '../../design/theme/colors.dart';
import 'pairing_api.dart';
import 'pairing_credentials.dart';
import 'widgets/pairing_error_note.dart';
import 'widgets/recovery_code_note.dart';
import 'widgets/devices_card.dart';
import '../chat/chat_api.dart';
import '../chat/chat_controller.dart';
import '../chat/chat_page.dart';
import 'pairing_session_gate.dart';
import '../../l10n/generated/app_localizations.dart';

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
  final _profileApi = PairingApi();
  late PairingSession _profileSession;
  int _tab = 0;
  int _lastUnread = 0;
  bool _loaded = false;
  bool _redirecting = false;
  bool _lifeNotice = true;

  @override
  void initState() {
    super.initState();
    _profileSession = widget.session;
    if (widget.session.profile == null || widget.session.partner == null) {
      unawaited(_loadProfiles());
    }
    WidgetsBinding.instance.addObserver(this);
    _chat = ChatController(widget.chatApi ?? ChatApi(widget.credentials))
      ..addListener(_changed);
    _chat.setForeground(
      WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    );
    _chat.start();
  }

  /// Reads server-owned identities after invitation, recovery or device login.
  Future<void> _loadProfiles() async {
    try {
      final session = await _profileApi.validateSession(
        widget.credentials.serverURL,
        widget.credentials.accessToken,
      );
      if (mounted) setState(() => _profileSession = session);
    } on Object {
      // A profile lookup must not interrupt an otherwise usable chat session.
    }
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
              AppLocalizations.of(
                context,
              )!.unreadFromPartner(_chat.unreadCount),
            ),
            action: SnackBarAction(
              label: AppLocalizations.of(context)!.openChat,
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
      if (index == 2) _lifeNotice = false;
    });
  }

  @override
  void dispose() {
    _profileApi.close();
    WidgetsBinding.instance.removeObserver(this);
    _chat.removeListener(_changed);
    _chat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HanddrawnScaffold(
      title: [l10n.ourConversation, l10n.onlineGames, l10n.lifeSpace][_tab],
      bottomNavigationBar: CrayonNavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _selectTab,
        chatLabel: _chat.unreadCount > 0
            ? l10n.chatUnread(_chat.unreadCount)
            : l10n.chat,
        gamesLabel: l10n.onlineGames,
        lifeLabel: l10n.life,
        unreadCount: _chat.unreadCount,
      ),
      body: Column(
        children: [
          if (_lifeNotice &&
              (widget.recoveryCodeToSave != null || widget.storageWarning))
            MaterialBanner(
              content: Text(
                widget.storageWarning
                    ? l10n.loginNotSaved
                    : l10n.saveRecoveryCodeLife,
              ),
              actions: [
                TextButton(
                  onPressed: () => _selectTab(2),
                  child: Text(l10n.viewLife),
                ),
              ],
            ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                ChatPage(controller: _chat, active: _tab == 0),
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: HanddrawnCard(child: Text(l10n.gamesComing)),
                  ),
                ),
                _LifeDetails(
                  credentials: widget.credentials,
                  session: _profileSession,
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
}

/// Keeps pairing details, devices and recovery notes in the shared Life tab.
class _LifeDetails extends StatelessWidget {
  const _LifeDetails({
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
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          HanddrawnCard(
            color: const Color(0xFFF4F0FF),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (session.profile != null || session.partner != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (session.profile case final profile?)
                        Expanded(
                          child: CoupleAvatar(
                            avatar: profile.avatar,
                            nickname: profile.nickname,
                            label: l10n.yourProfile,
                          ),
                        ),
                      const SizedBox(width: 16),
                      if (session.partner case final partner?)
                        Expanded(
                          child: CoupleAvatar(
                            avatar: partner.avatar,
                            nickname: partner.nickname,
                            label: l10n.partnerProfile,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                const NavigationDoodleIcon(
                  symbol: NavigationDoodle.life,
                  selected: true,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.lifeSpace,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: PawmateColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.connectedAsRole(session.role),
                  style: const TextStyle(
                    color: PawmateColors.softBrown,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.privateServer,
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
                    l10n.homeId(session.pairID!),
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
                  ? l10n.storageWarningRecovery
                  : l10n.storageWarningDevice,
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
