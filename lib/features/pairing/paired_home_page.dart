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
import '../chat/storage/chat_store.dart';
import '../chat/storage/chat_store_factory.dart';
import 'connection_status.dart';
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
    this.chatStore,
    this.pairingApi,
    this.verifySession = true,
  });

  final SavedPairingCredentials credentials;
  final PairingSession session;
  final String? recoveryCodeToSave;
  final bool storageWarning;
  final ChatApi? chatApi;
  final Future<ChatStore>? chatStore;
  final PairingApi? pairingApi;
  final bool verifySession;

  @override
  State<PairedHomePage> createState() => _PairedHomePageState();
}

class _PairedHomePageState extends State<PairedHomePage>
    with WidgetsBindingObserver {
  late final ChatController _chat;
  late final PairingApi _profileApi;
  final _connection = ValueNotifier(ConnectionStatus.checking);
  Timer? _connectionTimer;
  bool _checking = false;
  late final ValueNotifier<PairingSession> _profileSession;
  int _tab = 0;
  int _lastUnread = 0;
  bool _loaded = false;
  bool _detailsNotice = true;
  bool _viewingDetails = false;

  @override
  void initState() {
    super.initState();
    _profileSession = ValueNotifier(widget.session);
    _profileApi = widget.pairingApi ?? PairingApi();
    WidgetsBinding.instance.addObserver(this);
    final scope = ChatScope(
      serverURL: widget.credentials.serverURL,
      pairID: widget.credentials.pairID,
      role: widget.credentials.role,
    );
    _chat = ChatController(
      widget.chatApi ?? ChatApi(widget.credentials),
      store: widget.chatStore ?? openChatStore(scope),
      requireVerification: widget.verifySession,
    )..addListener(_changed);
    _chat.setForeground(
      WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    );
    _chat.start();
    unawaited(_restoreProfiles());
    if (widget.verifySession) {
      unawaited(_checkServer());
      _connectionTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (_chat.foreground && _connection.value == ConnectionStatus.offline) {
          unawaited(_checkServer());
        }
      });
    } else {
      _connection.value = ConnectionStatus.online;
    }
  }

  /// Restores identity asynchronously without overwriting a newer server response.
  Future<void> _restoreProfiles() async {
    await _chat.initialize();
    if (!mounted || _connection.value == ConnectionStatus.online) return;
    final cached = _chat.savedProfile;
    if (cached != null) {
      try {
        final session = PairingSession.fromJson(cached);
        if (session.pairID == widget.credentials.pairID &&
            session.role == widget.credentials.role) {
          _profileSession.value = session;
          setState(() {});
        }
      } on Object {
        /* Malformed cached profiles must not block the space. */
      }
    }
  }

  /// Checks both connectivity and access in the background, never blocking cached UI.
  Future<void> _checkServer() async {
    if (_checking || !mounted) return;
    _checking = true;
    _connection.value = ConnectionStatus.checking;
    try {
      final session = await _profileApi.validateSession(
        widget.credentials.serverURL,
        widget.credentials.accessToken,
      );
      if (!mounted) return;
      if (session.status != 'paired' ||
          session.pairID != widget.credentials.pairID ||
          session.role != widget.credentials.role) {
        _connection.value = ConnectionStatus.unauthorized;
        _chat.rejectAccess();
        return;
      }
      _profileSession.value = session;
      _connection.value = ConnectionStatus.online;
      _chat.allowNetwork(true);
      unawaited(_chat.saveProfile(session.toJson()));
    } on PairingApiException catch (error) {
      if (!mounted) return;
      _connection.value = error.statusCode == 401
          ? ConnectionStatus.unauthorized
          : ConnectionStatus.offline;
      if (error.statusCode == 401) {
        _chat.rejectAccess();
      } else {
        _chat.allowNetwork(false);
      }
    } on Object {
      if (mounted) {
        _connection.value = ConnectionStatus.offline;
        _chat.allowNetwork(false);
      }
    } finally {
      _checking = false;
      if (mounted) setState(() {});
    }
  }

  /// Pauses polling and read receipts when the application leaves the foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _chat.setForeground(state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed && widget.verifySession) {
      unawaited(_checkServer());
    }
  }

  /// Keeps offline/revoked sessions local; recovery is an explicit settings action.
  void _changed() {
    if (!mounted) return;
    if (_chat.unauthorized) {
      _connection.value = ConnectionStatus.unauthorized;
    } else if (_chat.error != null && !_checking) {
      _connection.value = ConnectionStatus.offline;
    } else if (_chat.error == null &&
        _connection.value == ConnectionStatus.offline &&
        !_checking) {
      // Only successful server sync, not cache hydration, can restore online status.
      if (_chat.caughtUp) _connection.value = ConnectionStatus.online;
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
    if (_viewingDetails) return;
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
              connection: _connection,
              onRetry: _checkServer,
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
    _connectionTimer?.cancel();
    _connection.dispose();
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
          ValueListenableBuilder<ConnectionStatus>(
            valueListenable: _connection,
            builder: (_, status, _) =>
                status == ConnectionStatus.offline ||
                    status == ConnectionStatus.unauthorized
                ? MaterialBanner(
                    content: Text(connectionLabel(l10n, status)),
                    actions: [
                      TextButton(
                        onPressed: _openDetails,
                        child: Text(l10n.openCoupleDetails),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          if (_chat.storageError)
            MaterialBanner(
              content: Text(l10n.localChatStorageError),
              actions: [
                TextButton(
                  onPressed: _openDetails,
                  child: Text(l10n.openCoupleDetails),
                ),
              ],
            ),
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
