import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/components/chat_message_bubble.dart';
import '../../design/components/handdrawn_card.dart';
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

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
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
        for (final entry in _incomingKeys.entries) {
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
    unawaited(widget.controller.send(text));
    _showLatest();
  }

  @override
  void dispose() {
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
      if (messages.isNotEmpty && widget.active) {
        _scheduleRead();
      }
      return Column(
        children: [
          if (chat.error != null)
            MaterialBanner(
              content: Text(l10n.chatError),
              actions: [
                TextButton(
                  onPressed: () => chat.synchronize(),
                  child: Text(l10n.retry),
                ),
              ],
            ),
          Expanded(
            child: SizedBox.expand(
              key: _viewportKey,
              child: chat.loading
                  ? const Center(child: CircularProgressIndicator())
                  : messages.isEmpty && pending.isEmpty
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
                          status: own
                              ? (message.id <= chat.partnerReadID
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
