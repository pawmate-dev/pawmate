import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/components/handdrawn_card.dart';
import '../../design/components/crayon_navigation_bar.dart';
import '../../design/components/couple_header_avatars.dart';
import '../../design/theme/spacing.dart';
import '../../design/layouts/handdrawn_scaffold.dart';
import 'pairing_api.dart';
import 'couple_details_page.dart';
import 'pairing_credentials.dart';
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
  late final ValueNotifier<PairingSession> _profileSession;
  int _tab = 0;
  int _lastUnread = 0;
  bool _loaded = false;
  bool _redirecting = false;
  bool _detailsNotice = true;
  bool _viewingDetails = false;

  @override
  void initState() {
    super.initState();
    _profileSession = ValueNotifier(widget.session);
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
      if (mounted) setState(() => _profileSession.value = session);
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
        (_tab != 0 || _viewingDetails) &&
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
              onPressed: _openChat,
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
    _chat.setChatVisible(index == 0 && !_viewingDetails);
    setState(() {
      _tab = index;
    });
  }

  /// Covers chat without marking messages read, then restores the selected tab.
  Future<void> _openDetails() async {
    if (_viewingDetails || _redirecting) return;
    _chat.setChatVisible(false);
    setState(() {
      _viewingDetails = true;
      _detailsNotice = false;
    });
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ValueListenableBuilder<PairingSession>(
            valueListenable: _profileSession,
            builder: (_, session, _) => CoupleDetailsPage(
              credentials: widget.credentials,
              session: session,
              recoveryCodeToSave: widget.recoveryCodeToSave,
              storageWarning: widget.storageWarning,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _viewingDetails = false);
        _chat.setChatVisible(_tab == 0);
      }
    }
  }

  /// An unread reminder returns to chat even when the details route is on top.
  void _openChat() {
    _selectTab(0);
    if (_viewingDetails) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _profileSession.dispose();
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
      title: null,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: PawmateSpace.large),
          child: Center(
            child: CoupleHeaderButton(
              label: l10n.openCoupleDetails,
              onPressed: _openDetails,
              child: CoupleHeaderAvatars(
                memberAvatar: _profileSession.value.profile?.avatar,
                partnerAvatar: _profileSession.value.partner?.avatar,
                memberNickname: _profileSession.value.profile?.nickname,
                partnerNickname: _profileSession.value.partner?.nickname,
                memberLabel: l10n.yourProfile,
                partnerLabel: l10n.partnerProfile,
              ),
            ),
          ),
        ),
      ],
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
          if (_tab != 2 &&
              _detailsNotice &&
              (widget.recoveryCodeToSave != null || widget.storageWarning))
            MaterialBanner(
              content: Text(
                widget.storageWarning
                    ? l10n.loginNotSaved
                    : l10n.saveRecoveryCodeDetails,
              ),
              actions: [
                TextButton(
                  onPressed: _openDetails,
                  child: Text(l10n.openCoupleDetails),
                ),
              ],
            ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                ChatPage(
                  controller: _chat,
                  active: _tab == 0 && !_viewingDetails,
                ),
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: HanddrawnCard(child: Text(l10n.gamesComing)),
                  ),
                ),
                const SizedBox.expand(key: ValueKey('life-empty-content')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
