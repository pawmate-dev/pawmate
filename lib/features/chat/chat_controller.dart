import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../pairing/pairing_api.dart';
import 'chat_api.dart';

/// A local outgoing message keeps the same id during ambiguous network retries.
class OutgoingMessage {
  OutgoingMessage(this.clientID, this.text);
  final String clientID;
  final String text;
  bool sending = true;
}

/// Shares messages, receipts and an in-memory outbox across the couple-space tabs.
class ChatController extends ChangeNotifier {
  ChatController(this.api);

  final ChatApi api;
  final List<ChatMessage> _messages = [];
  final List<OutgoingMessage> _outbox = [];
  Timer? _timer;
  bool _disposed = false;
  bool _syncing = false;
  bool _reading = false;
  bool _historyLoading = false;
  bool _foreground = true;
  bool _chatVisible = true;
  DateTime? _readRetryAt;
  int _knownLatestID = 0;
  int _syncAfter = 0;
  int _requestedReadID = 0;
  int _readID = 0;
  int partnerReadID = 0;
  int unreadCount = 0;
  bool loaded = false;
  bool hasOlder = false;
  bool unauthorized = false;
  String? error;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<OutgoingMessage> get outbox => List.unmodifiable(_outbox);
  bool get loading => !loaded && _syncing;
  bool get historyLoading => _historyLoading;
  bool get foreground => _foreground;
  bool get caughtUp => loaded && _syncAfter >= _knownLatestID;

  /// Stops queued read advances as soon as another tab becomes visible.
  void setChatVisible(bool visible) {
    _chatVisible = visible;
  }

  /// Polls only while the application is foregrounded; history stays in memory.
  void start() {
    unawaited(synchronize());
    _timer ??= Timer.periodic(const Duration(seconds: 2), (_) {
      if (_foreground) unawaited(synchronize());
    });
  }

  /// Resumes synchronization after backgrounding without generating read receipts.
  void setForeground(bool foreground) {
    _foreground = foreground;
    if (foreground) unawaited(synchronize());
    _emit();
  }

  /// Fetches every forward page; sending locally never advances the fetch cursor.
  Future<void> synchronize() async {
    if (_disposed || _syncing || unauthorized) return;
    _syncing = true;
    _emit();
    try {
      bool more;
      do {
        final previous = _syncAfter;
        final snapshot = await api.messages(afterID: _syncAfter);
        if (_disposed) return;
        _merge(snapshot.messages);
        if (_syncAfter == 0) hasOlder = snapshot.hasMore;
        if (snapshot.messages.isNotEmpty) {
          _syncAfter = snapshot.messages.last.id;
        }
        _applyReceipts(snapshot);
        loaded = true;
        error = null;
        // Initial history is the most recent window, not an ascending delta page.
        more = previous > 0 && snapshot.hasMore && _syncAfter > previous;
        _emit();
      } while (more && !_disposed);
    } catch (failure) {
      _handleError(failure);
    } finally {
      _syncing = false;
      _emit();
    }
  }

  /// Prepends older history without changing the independent forward cursor.
  Future<void> loadOlder() async {
    if (_disposed || _historyLoading || !hasOlder || _messages.isEmpty) return;
    _historyLoading = true;
    _emit();
    try {
      final snapshot = await api.messages(beforeID: _messages.first.id);
      if (_disposed) return;
      _merge(snapshot.messages);
      hasOlder = snapshot.hasMore;
      error = null;
    } catch (failure) {
      _handleError(failure);
    } finally {
      _historyLoading = false;
      _emit();
    }
  }

  /// Queues a new message using a cryptographically random, retry-safe client id.
  Future<void> send(String text) async {
    text = text.trim();
    if (_disposed || text.isEmpty || text.runes.length > 4000) return;
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final outgoing = OutgoingMessage(id, text);
    _outbox.add(outgoing);
    _emit();
    await _send(outgoing);
  }

  /// Retries failed text with its original client id to prevent duplicate messages.
  Future<void> retry(OutgoingMessage outgoing) async {
    if (_disposed || outgoing.sending || !_outbox.contains(outgoing)) return;
    outgoing.sending = true;
    _emit();
    await _send(outgoing);
  }

  /// Reconciles the response with messages already observed through polling.
  Future<void> _send(OutgoingMessage outgoing) async {
    try {
      final message = await api.send(outgoing.clientID, outgoing.text);
      if (_disposed) return;
      _merge([message]);
      _outbox.remove(outgoing);
      unawaited(synchronize());
    } catch (failure) {
      if (!_disposed) outgoing.sending = false;
      _handleError(failure);
    }
    _emit();
  }

  /// Marks only the rendered cursor supplied by the visible, foreground chat page.
  Future<void> markVisibleRead(int id) async {
    if (_disposed ||
        !_foreground ||
        !_chatVisible ||
        !caughtUp ||
        id <= _readID ||
        unauthorized ||
        (_readRetryAt != null && DateTime.now().isBefore(_readRetryAt!))) {
      return;
    }
    _requestedReadID = max(_requestedReadID, id);
    if (_reading) return;
    _reading = true;
    try {
      while (_requestedReadID > _readID &&
          _foreground &&
          _chatVisible &&
          !_disposed) {
        final read = await api.markRead(_requestedReadID);
        if (_disposed) return;
        _readID = max(_readID, read);
        _readRetryAt = null;
        _emit();
      }
      // Only a fresh server snapshot can count messages arriving during the receipt.
      unawaited(synchronize());
    } catch (failure) {
      _readRetryAt = DateTime.now().add(const Duration(seconds: 2));
      _handleError(failure);
    } finally {
      _reading = false;
      _emit();
    }
  }

  /// Merges by server id and removes outbox echoes sent by this installation.
  void _merge(List<ChatMessage> incoming) {
    final byID = {for (final message in _messages) message.id: message};
    for (final message in incoming) {
      _knownLatestID = max(_knownLatestID, message.id);
      byID[message.id] = message;
      if (message.sender == api.credentials.role) {
        _outbox.removeWhere(
          (outgoing) => outgoing.clientID == message.clientID,
        );
      }
    }
    _messages
      ..clear()
      ..addAll(byID.values);
    _messages.sort((a, b) => a.id.compareTo(b.id));
  }

  /// Never regresses read receipts when an older in-flight snapshot completes.
  void _applyReceipts(ChatSnapshot snapshot) {
    _knownLatestID = max(_knownLatestID, snapshot.latestID);
    partnerReadID = max(partnerReadID, snapshot.partnerReadID);
    _readID = max(_readID, snapshot.readID);
    // Ignore stale unread metadata after a newer local read acknowledgment.
    if (snapshot.readID >= _readID) unreadCount = snapshot.unreadCount;
  }

  /// Reports connectivity failures without exposing private message content.
  void _handleError(Object failure) {
    if (_disposed) return;
    if (failure is PairingApiException && failure.statusCode == 401) {
      unauthorized = true;
    }
    error = 'Messages could not synchronize. Check your connection and retry.';
  }

  /// Guards against asynchronous completions after leaving the couple space.
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    api.close();
    super.dispose();
  }
}
