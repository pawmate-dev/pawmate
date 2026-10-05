import 'dart:convert';

import '../../pairing/pairing_api.dart';
import '../chat_api.dart';

/// Identifies one member's cache without retaining their bearer or recovery code.
class ChatScope {
  ChatScope({
    required String serverURL,
    required this.pairID,
    required this.role,
  }) : serverURL = PairingApi.parseServerURL(serverURL).toString();

  final String serverURL;
  final String pairID;
  final String role;
  String get key => jsonEncode([serverURL, pairID, role]);
}

/// A message that must retain its idempotency key across crashes and restarts.
class StoredOutgoing {
  const StoredOutgoing(this.clientID, this.text, {this.createdAt});
  final String clientID;
  final String text;
  final DateTime? createdAt;
}

/// Only server synchronization is allowed to advance these member-owned cursors.
class ChatSyncState {
  const ChatSyncState({
    this.afterID = 0,
    this.latestID = 0,
    this.readID = 0,
    this.partnerReadID = 0,
    this.unreadCount = 0,
    this.hasOlder = false,
    this.historyBeforeID = 0,
  });
  final int afterID;
  final int latestID;
  final int readID;
  final int partnerReadID;
  final int unreadCount;
  final bool hasOlder;
  final int historyBeforeID;
}

/// A bounded, versioned exchange page independent of Bluetooth, LAN or files.
/// The future transport must authenticate the peer and encrypt its channel.
class ChatHistoryBatch {
  const ChatHistoryBatch({
    required this.serverURL,
    required this.pairID,
    required this.messages,
    this.version = 1,
  });
  static const maxMessages = 250;
  final int version;
  final String serverURL;
  final String pairID;
  final List<ChatMessage> messages;

  /// Excludes tokens, recovery codes, profiles, outbox and read/sync cursors.
  Map<String, dynamic> toJson() => {
    'version': version,
    'server_url': serverURL,
    'pair_id': pairID,
    'messages': messages.map((message) => message.toJson()).toList(),
  };

  /// Rejects unsupported or oversized pages before deserializing message rows.
  factory ChatHistoryBatch.fromJson(Map<String, dynamic> value) {
    final rows = value['messages'];
    if (value['version'] != 1 || rows is! List || rows.length > maxMessages) {
      throw const FormatException('Unsupported history exchange page');
    }
    return ChatHistoryBatch(
      version: value['version'] as int,
      serverURL: value['server_url'] as String,
      pairID: value['pair_id'] as String,
      messages: rows
          .map((row) => ChatMessage.fromJson(row as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Transport-neutral extension point for server backups and device-to-device history.
abstract interface class ChatHistoryExchange {
  Future<ChatHistoryBatch> exportHistory({int afterID = 0, int limit = 250});
  Future<int> importHistory(ChatHistoryBatch batch);
}

/// Persistent storage contract; each instance is permanently bound to one scope.
abstract class ChatStore implements ChatHistoryExchange {
  ChatScope get scope;
  Future<List<ChatMessage>> messages({int? beforeID, int limit = 50});
  Future<ChatSyncState> syncState();
  Future<void> commit(List<ChatMessage> messages, {ChatSyncState? state});
  Future<List<StoredOutgoing>> outbox();
  Future<void> putOutgoing(StoredOutgoing message);
  Future<void> removeOutgoing(String clientID);
  Future<String> draft();
  Future<void> saveDraft(String text);
  Future<Map<String, dynamic>?> profile();
  Future<void> saveProfile(Map<String, dynamic> profile);
  Future<void> close();

  /// Validates the entire exchange before any writes; imports never trust receipts.
  void validateBatch(ChatHistoryBatch batch) {
    if (batch.version != 1 ||
        batch.messages.length > ChatHistoryBatch.maxMessages ||
        batch.serverURL != scope.serverURL ||
        batch.pairID != scope.pairID) {
      throw const FormatException(
        'History belongs to another instance or pair',
      );
    }
    final ids = <int>{};
    final clients = <String>{};
    for (final message in batch.messages) {
      if (message.id <= 0 ||
          message.clientID.isEmpty ||
          message.clientID.length > 128 ||
          !['inviter', 'invitee'].contains(message.sender) ||
          message.text.trim().isEmpty ||
          message.text.runes.length > 4000 ||
          !ids.add(message.id) ||
          !clients.add('${message.sender}:${message.clientID}')) {
        throw const FormatException('Invalid history message');
      }
    }
  }
}

/// In-memory implementation for injected tests and unsupported browser storage.
class MemoryChatStore extends ChatStore {
  MemoryChatStore(this.scope);
  @override
  final ChatScope scope;
  final rows = <int, ChatMessage>{};
  final pending = <String, StoredOutgoing>{};
  ChatSyncState state = const ChatSyncState();
  String textDraft = '';
  Map<String, dynamic>? memberProfile;

  @override
  Future<List<ChatMessage>> messages({int? beforeID, int limit = 50}) async {
    final result =
        rows.values
            .where((row) => beforeID == null || row.id < beforeID)
            .toList()
          ..sort((a, b) => b.id.compareTo(a.id));
    return result.take(limit).toList().reversed.toList();
  }

  @override
  Future<ChatSyncState> syncState() async => state;
  @override
  Future<void> commit(
    List<ChatMessage> messages, {
    ChatSyncState? state,
  }) async {
    for (final row in messages) {
      if (row.serverConfirmed) {
        rows.removeWhere(
          (_, old) =>
              !old.serverConfirmed &&
              old.id != row.id &&
              old.sender == row.sender &&
              old.clientID == row.clientID,
        );
      }
      rows[row.id] = row;
      if (row.serverConfirmed && row.sender == scope.role) {
        pending.remove(row.clientID);
      }
    }
    if (state != null) this.state = state;
  }

  @override
  Future<List<StoredOutgoing>> outbox() async => pending.values.toList();
  @override
  Future<void> putOutgoing(StoredOutgoing row) async =>
      pending[row.clientID] = row;
  @override
  Future<void> removeOutgoing(String clientID) async =>
      pending.remove(clientID);
  @override
  Future<String> draft() async => textDraft;
  @override
  Future<void> saveDraft(String text) async => textDraft = text;
  @override
  Future<Map<String, dynamic>?> profile() async => memberProfile;
  @override
  Future<void> saveProfile(Map<String, dynamic> profile) async =>
      memberProfile = profile;
  @override
  Future<void> close() async {}
  @override
  Future<ChatHistoryBatch> exportHistory({
    int afterID = 0,
    int limit = 250,
  }) async {
    if (limit < 1 || limit > ChatHistoryBatch.maxMessages) {
      throw ArgumentError.value(limit);
    }
    final selected = rows.values.where((row) => row.id > afterID).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return ChatHistoryBatch(
      serverURL: scope.serverURL,
      pairID: scope.pairID,
      messages: selected.take(limit).toList(),
    );
  }

  @override
  Future<int> importHistory(ChatHistoryBatch batch) async {
    validateBatch(batch);
    for (final row in batch.messages) {
      final existing = rows[row.id];
      if (existing != null &&
          jsonEncode(existing.toJson()) != jsonEncode(row.toJson())) {
        throw const FormatException('Conflicting history message');
      }
      if (rows.values.any(
        (old) =>
            old.id != row.id &&
            old.sender == row.sender &&
            old.clientID == row.clientID,
      )) {
        throw const FormatException('Conflicting history identity');
      }
    }
    var count = 0;
    for (final row in batch.messages) {
      if (rows.containsKey(row.id)) continue;
      rows[row.id] = ChatMessage(
        id: row.id,
        clientID: row.clientID,
        sender: row.sender,
        text: row.text,
        createdAt: row.createdAt,
        serverConfirmed: false,
      );
      count++;
    }
    return count;
  }
}
