import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../pairing/pairing_api.dart';
import 'chat_api.dart';
import 'storage/chat_store.dart';

/// A local outgoing message keeps the same id during ambiguous network retries.
class OutgoingMessage {
  OutgoingMessage(this.clientID, this.text);
  final String clientID;
  final String text;
  bool sending = true;
}

/// Shares a persistent local history, drafts and outbox across couple-space tabs.
class ChatController extends ChangeNotifier {
  ChatController(
    this.api, {
    Future<ChatStore>? store,
    bool requireVerification = false,
  }) : _storeFuture =
           store ??
           Future.value(
             MemoryChatStore(
               ChatScope(
                 serverURL: api.credentials.serverURL,
                 pairID: api.credentials.pairID,
                 role: api.credentials.role,
               ),
             ),
           ),
       _accessAllowed = !requireVerification;

  final ChatApi api;
  final Future<ChatStore> _storeFuture;
  late ChatStore _store;
  Future<void>? _initialization;
  bool initialized = false;
  bool storageError = false;
  bool _accessAllowed;
  bool _started = false;
  bool _serverSynced = false;
  bool _localOlder = false;
  bool _serverOlder = false;
  bool _draftEdited = false;
  Future<void> _writes = Future.value();
  int _historyBeforeID = 0;
  String savedDraft = '';
  Map<String, dynamic>? savedProfile;
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
  bool get loading => false;
  bool get historyLoading => _historyLoading;
  bool get foreground => _foreground;
  bool get caughtUp => loaded && _serverSynced && _syncAfter >= _knownLatestID;

  /// Reads only one local page, without waiting for any server connection.
  Future<void> initialize() => _initialization ??= _restore();

  Future<void> _restore() async {
    ChatStore? opened;
    try {
      _store = await _storeFuture;
      opened = _store;
      final state = await _store.syncState();
      final rows = await _store.messages(limit: 51);
      if (_disposed) {
        await _store.close();
        return;
      }
      _localOlder = rows.length > 50;
      _merge(rows.length > 50 ? rows.sublist(1) : rows);
      _syncAfter = state.afterID;
      _knownLatestID = max(_knownLatestID, state.latestID);
      _readID = state.readID;
      partnerReadID = state.partnerReadID;
      unreadCount = state.unreadCount;
      _serverOlder = state.hasOlder;
      _historyBeforeID = state.historyBeforeID;
      hasOlder = _localOlder || _serverOlder;
      for (final pending in await _store.outbox()) {
        _outbox.add(
          OutgoingMessage(pending.clientID, pending.text)..sending = false,
        );
      }
      final draft = await _store.draft();
      if (!_draftEdited) savedDraft = draft;
      savedProfile = await _store.profile();
      if (_disposed) {
        await _store.close();
        return;
      }
    } on Object {
      if (opened != null) {
        try {
          await opened.close();
        } on Object {
          /* Preserve the cache on disk. */
        }
      }
      if (_disposed) return;
      storageError = true;
      _store = MemoryChatStore(
        ChatScope(
          serverURL: api.credentials.serverURL,
          pairID: api.credentials.pairID,
          role: api.credentials.role,
        ),
      );
    }
    initialized = true;
    loaded = true;
    _emit();
  }

  /// Controls protected requests separately from whether cached data is visible.
  void allowNetwork(bool allowed) {
    _accessAllowed = allowed;
    if (allowed) unauthorized = false;
    if (allowed && _started && _foreground) unawaited(synchronize());
  }

  /// Keeps cached history readable while explicitly disabling revoked device access.
  void rejectAccess() {
    _accessAllowed = false;
    unauthorized = true;
    _emit();
  }

  /// Database failure never becomes a network failure or advances a durable cursor.
  Future<void> _persist(Future<void> Function() operation) async {
    if (storageError || _disposed) return;
    _writes = _writes.then((_) async {
      if (storageError) return;
      try {
        await operation();
      } on Object {
        storageError = true;
        _emit();
      }
    });
    await _writes;
  }

  ChatSyncState get _state => ChatSyncState(
    afterID: _syncAfter,
    latestID: _knownLatestID,
    readID: _readID,
    partnerReadID: partnerReadID,
    unreadCount: unreadCount,
    hasOlder: _serverOlder,
    historyBeforeID: _historyBeforeID,
  );

  /// Exports a bounded content page for a future authenticated device transport.
  Future<ChatHistoryBatch> exportHistory({
    int afterID = 0,
    int limit = 250,
  }) async {
    await initialize();
    return _store.exportHistory(afterID: afterID, limit: limit);
  }

  /// Imports untrusted content without trusting a peer's sync or read positions.
  Future<int> importHistory(ChatHistoryBatch batch) async {
    await initialize();
    final count = await _store.importHistory(batch);
    final rows = await _store.messages(limit: 51);
    _localOlder = rows.length > 50;
    _merge(rows.length > 50 ? rows.sublist(1) : rows);
    hasOlder = _localOlder || _serverOlder;
    _emit();
    return count;
  }

  /// Persists a bounded draft independently of server reachability.
  Future<void> saveDraft(String text) async {
    updateDraft(text);
    await initialize();
    await _persist(() => _store.saveDraft(text));
  }

  /// Retains the latest keystroke even when the widget disappears before debounce.
  void updateDraft(String text) {
    savedDraft = text;
    _draftEdited = true;
  }

  /// Caches only the already-authenticated member profiles, not bearer credentials.
  Future<void> saveProfile(Map<String, dynamic> profile) async {
    await initialize();
    savedProfile = profile;
    await _persist(() => _store.saveProfile(profile));
  }

  /// Stops queued read advances as soon as another tab becomes visible.
  void setChatVisible(bool visible) {
    _chatVisible = visible;
  }

  /// Polls only while the application is foregrounded; history stays in memory.
  void start() {
    _started = true;
    unawaited(initialize().then((_) => synchronize()));
    _timer ??= Timer.periodic(const Duration(seconds: 2), (_) {
      if (_foreground) unawaited(synchronize());
    });
  }

  /// Resumes synchronization after backgrounding without generating read receipts.
  void setForeground(bool foreground) {
    _foreground = foreground;
    if (foreground && _started) unawaited(synchronize());
    _emit();
  }

  /// Fetches every forward page; sending locally never advances the fetch cursor.
  Future<void> synchronize() async {
    await initialize();
    if (_disposed ||
        _syncing ||
        unauthorized ||
        !_accessAllowed ||
        !_foreground) {
      return;
    }
    _syncing = true;
    _emit();
    try {
      bool more;
      do {
        final previous = _syncAfter;
        final snapshot = await api.messages(afterID: _syncAfter);
        if (_disposed) return;
        _merge(snapshot.messages);
        if (_syncAfter == 0) {
          _serverOlder = snapshot.hasMore;
          if (snapshot.messages.isNotEmpty) {
            _historyBeforeID = snapshot.messages.first.id;
          }
        }
        if (snapshot.messages.isNotEmpty) {
          _syncAfter = snapshot.messages.last.id;
        }
        _applyReceipts(snapshot);
        _serverSynced = true;
        hasOlder = _localOlder || _serverOlder;
        final state = _state;
        await _persist(() => _store.commit(snapshot.messages, state: state));
        loaded = true;
        error = null;
        // Initial history is the most recent window, not an ascending delta page.
        more = previous > 0 && snapshot.hasMore && _syncAfter > previous;
        _emit();
      } while (more && !_disposed);
      // Restarted and offline sends keep their original ids until reconciliation.
      for (final outgoing in _outbox.toList()) {
        if (!_disposed && _accessAllowed && !outgoing.sending) {
          outgoing.sending = true;
          await _send(outgoing);
        }
      }
    } catch (failure) {
      _handleError(failure);
    } finally {
      _syncing = false;
      _emit();
    }
  }

  /// Prepends older history without changing the independent forward cursor.
  Future<void> loadOlder() async {
    await initialize();
    if (_disposed || _historyLoading || !hasOlder || _messages.isEmpty) return;
    _historyLoading = true;
    _emit();
    try {
      final cached = await _store.messages(
        beforeID: _messages.first.id,
        limit: 51,
      );
      if (_disposed) return;
      if (cached.isNotEmpty) {
        _localOlder = cached.length > 50;
        _merge(cached.length > 50 ? cached.sublist(1) : cached);
        hasOlder = _localOlder || _serverOlder;
        return;
      }
      if (!_accessAllowed || unauthorized) return;
      final snapshot = await api.messages(
        beforeID: _historyBeforeID > 0 ? _historyBeforeID : _messages.first.id,
      );
      if (_disposed) return;
      _merge(snapshot.messages);
      _serverOlder = snapshot.hasMore;
      if (snapshot.messages.isNotEmpty) {
        _historyBeforeID = snapshot.messages.first.id;
      }
      hasOlder = _serverOlder;
      final state = _state;
      await _persist(() => _store.commit(snapshot.messages, state: state));
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
    await initialize();
    text = text.trim();
    if (_disposed || text.isEmpty || text.runes.length > 4000) return;
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final outgoing = OutgoingMessage(id, text);
    _outbox.add(outgoing);
    await _persist(() => _store.putOutgoing(StoredOutgoing(id, text)));
    if (!_accessAllowed || unauthorized) {
      outgoing.sending = false;
      _emit();
      return;
    }
    _emit();
    await _send(outgoing);
  }

  /// Retries failed text with its original client id to prevent duplicate messages.
  Future<void> retry(OutgoingMessage outgoing) async {
    if (_disposed ||
        outgoing.sending ||
        !_outbox.contains(outgoing) ||
        !_accessAllowed ||
        unauthorized) {
      return;
    }
    outgoing.sending = true;
    _emit();
    await _send(outgoing);
  }

  /// Reconciles the response with messages already observed through polling.
  Future<void> _send(OutgoingMessage outgoing) async {
    if (_disposed || !_accessAllowed || unauthorized) {
      outgoing.sending = false;
      return;
    }
    try {
      final message = await api.send(outgoing.clientID, outgoing.text);
      if (_disposed) return;
      _merge([message]);
      await _persist(() => _store.commit([message]));
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
        !_accessAllowed ||
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
          _accessAllowed &&
          !unauthorized &&
          !_disposed) {
        final read = await api.markRead(_requestedReadID);
        if (_disposed) return;
        _readID = max(_readID, read);
        final state = _state;
        await _persist(() => _store.commit([], state: state));
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
      if (message.serverConfirmed) {
        byID.removeWhere(
          (_, old) =>
              !old.serverConfirmed &&
              old.id != message.id &&
              old.sender == message.sender &&
              old.clientID == message.clientID,
        );
      }
      if (message.serverConfirmed) {
        _knownLatestID = max(_knownLatestID, message.id);
      }
      byID[message.id] = message;
      if (message.serverConfirmed && message.sender == api.credentials.role) {
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
      _accessAllowed = false;
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
    if (initialized) {
      unawaited(
        _writes.then((_) async {
          if (!storageError) {
            try {
              await _store.saveDraft(savedDraft);
            } on Object {
              /* Keep the existing database intact. */
            }
          }
          await _store.close();
        }),
      );
    }
    super.dispose();
  }
}
