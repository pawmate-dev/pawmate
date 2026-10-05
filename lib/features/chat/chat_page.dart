import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/components/chat_message_bubble.dart';
import '../../design/components/handdrawn_card.dart';
import '../../design/icons/chat/message_status_icon.dart';
import 'chat_controller.dart';
import '../../l10n/generated/app_localizations.dart';

/// The default couple-space tab, with text history and visibility-based receipts.
class ChatPage extends StatefulWidget {
  const ChatPage({required this.controller, required this.active, super.key});

  final ChatController controller;
  final bool active;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _draft = TextEditingController();
  final _scroll = ScrollController();
  final _viewportKey = GlobalKey();
  final Map<int, GlobalKey> _incomingKeys = {};
  bool _atLatest = true;
  bool _draftRestored = false;
  Timer? _draftTimer;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    widget.controller.addListener(_restoreDraft);
    _restoreDraft();
  }

  /// Applies the cached draft once; later synchronization never overwrites typing.
  void _restoreDraft() {
    if (_draftRestored || !widget.controller.initialized) return;
    _draftRestored = true;
    if (_draft.text.isEmpty) _draft.text = widget.controller.savedDraft;
  }

  /// Coalesces keystrokes; disposing flushes the last edit before closing storage.
  void _saveDraft(String text) {
    widget.controller.updateDraft(text);
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(widget.controller.saveDraft(text));
    });
  }

  /// Reads incoming messages inside the rendered viewport, never on fetch alone.
  void _scheduleRead() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.active &&
          widget.controller.foreground &&
          _scroll.hasClients) {
        final viewport = _viewportKey.currentContext?.findRenderObject();
        if (viewport is! RenderBox || !viewport.hasSize) return;
        final bounds = viewport.localToGlobal(Offset.zero) & viewport.size;
        var visibleID = 0;
        final confirmed = widget.controller.messages
            .where((message) => message.serverConfirmed)
            .map((message) => message.id)
            .toSet();
        for (final entry in _incomingKeys.entries) {
          if (!confirmed.contains(entry.key)) continue;
          final bubble = entry.value.currentContext?.findRenderObject();
          if (bubble is RenderBox && bubble.hasSize) {
            final messageBounds =
                bubble.localToGlobal(Offset.zero) & bubble.size;
            if (messageBounds.overlaps(bounds) && entry.key > visibleID) {
              visibleID = entry.key;
            }
          }
        }
        if (visibleID > 0) {
          unawaited(widget.controller.markVisibleRead(visibleID));
        }
      }
    });
  }

  /// Keeps unread messages unread while browsing earlier history.
  void _onScroll() {
    final atLatest = _scroll.offset <= 24;
    if (_atLatest != atLatest) setState(() => _atLatest = atLatest);
    if (widget.controller.messages.isNotEmpty) {
      _scheduleRead();
    }
  }

  /// Jumps to the latest message using the user's animation preference.
  void _showLatest() {
    if (!_scroll.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(0);
    } else {
      unawaited(
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        ),
      );
    }
  }

  /// Sends a valid draft while retaining independent failed messages for retry.
  void _send() {
    final text = _draft.text.trim();
    if (text.isEmpty || text.runes.length > 4000) return;
    _draft.clear();
    _draftTimer?.cancel();
    unawaited(widget.controller.saveDraft(''));
    unawaited(widget.controller.send(text));
    _showLatest();
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    widget.controller.removeListener(_restoreDraft);
    unawaited(widget.controller.saveDraft(_draft.text));
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final l10n = AppLocalizations.of(context)!;
      final chat = widget.controller;
      final messages = chat.messages.reversed.toList();
      final pending = chat.outbox.reversed.toList();
      // A run ends when the newer item changes sender or is over five minutes away.
      bool groupEnd(int index, String sender, DateTime time) {
        if (index == 0) return true;
        final newerIndex = index - 1;
        if (newerIndex < pending.length) {
          return sender != chat.api.credentials.role ||
              pending[newerIndex].createdAt.difference(time).abs() >
                  const Duration(minutes: 5);
        }
        final newer = messages[newerIndex - pending.length];
        return newer.sender != sender ||
            newer.createdAt.difference(time).abs() > const Duration(minutes: 5);
      }

      if (messages.isNotEmpty && widget.active) {
        _scheduleRead();
      }
      return Column(
        children: [
          Expanded(
            child: SizedBox.expand(
              key: _viewportKey,
              child: messages.isEmpty && pending.isEmpty
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: HanddrawnCard(child: Text(l10n.firstWords)),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount:
                          pending.length +
                          messages.length +
                          (chat.hasOlder ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < pending.length) {
                          final outgoing = pending[index];
                          return ChatMessageBubble(
                            key: ValueKey('pending-${outgoing.clientID}'),
                            text: outgoing.text,
                            own: true,
                            time: outgoing.createdAt,
                            isGroupEnd: groupEnd(
                              index,
                              chat.api.credentials.role,
                              outgoing.createdAt,
                            ),
                            delivery: outgoing.sending
                                ? MessageDelivery.sending
                                : MessageDelivery.failed,
                            status: outgoing.sending
                                ? l10n.sending
                                : l10n.notSent,
                            onRetry: outgoing.sending
                                ? null
                                : () => chat.retry(outgoing),
                          );
                        }
                        final messageIndex = index - pending.length;
                        if (messageIndex >= messages.length) {
                          return TextButton(
                            onPressed: chat.historyLoading
                                ? null
                                : () => chat.loadOlder(),
                            child: Text(
                              chat.historyLoading
                                  ? l10n.loading
                                  : l10n.loadEarlier,
                            ),
                          );
                        }
                        final message = messages[messageIndex];
                        final own = message.sender == chat.api.credentials.role;
                        return ChatMessageBubble(
                          key: own
                              ? ValueKey(message.id)
                              : _incomingKeys.putIfAbsent(
                                  message.id,
                                  () => GlobalKey(),
                                ),
                          text: message.text,
                          own: own,
                          time: message.createdAt,
                          isGroupEnd: groupEnd(
                            index,
                            message.sender,
                            message.createdAt,
                          ),
                          delivery: own
                              ? (!message.serverConfirmed
                                    ? MessageDelivery.sending
                                    : message.id <= chat.partnerReadID
                                    ? MessageDelivery.read
                                    : MessageDelivery.sent)
                              : null,
                          status: own
                              ? (!message.serverConfirmed
                                    ? l10n.sending
                                    : message.id <= chat.partnerReadID
                                    ? l10n.read
                                    : l10n.unread)
                              : '',
                        );
                      },
                    ),
            ),
          ),
          if (!_atLatest && chat.unreadCount > 0)
            TextButton.icon(
              onPressed: _showLatest,
              icon: const Icon(Icons.arrow_downward),
              label: Text(l10n.unreadGoLatest(chat.unreadCount)),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _draft,
                builder: (context, draft, _) => Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: _saveDraft,
                        controller: _draft,
                        minLines: 1,
                        maxLines: 4,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          labelText: l10n.messagePartner,
                          errorText: draft.text.runes.length > 4000
                              ? l10n.messageTooLong
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: l10n.sendMessage,
                      onPressed:
                          draft.text.trim().isEmpty ||
                              draft.text.runes.length > 4000 ||
                              chat.unauthorized
                          ? null
                          : _send,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
