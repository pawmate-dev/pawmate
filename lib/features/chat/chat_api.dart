import 'dart:convert';

import 'package:http/http.dart' as http;

import '../pairing/pairing_api.dart';
import '../pairing/pairing_credentials.dart';

/// A text message whose identity and order are assigned by the private server.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.clientID,
    required this.sender,
    required this.text,
    required this.createdAt,
  });

  /// Decodes a persisted message, including messages from this member's other devices.
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as int,
    clientID: json['client_id'] as String,
    sender: json['sender'] as String,
    text: json['text'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  final int id;
  final String clientID;
  final String sender;
  final String text;
  final DateTime createdAt;
}

/// History and shared member-level receipts returned in a single snapshot.
class ChatSnapshot {
  const ChatSnapshot({
    required this.messages,
    required this.hasMore,
    required this.latestID,
    required this.readID,
    required this.partnerReadID,
    required this.unreadCount,
  });

  /// Decodes message pagination and the current unread count.
  factory ChatSnapshot.fromJson(Map<String, dynamic> json) => ChatSnapshot(
    messages: (json['messages'] as List<dynamic>)
        .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
        .toList(),
    hasMore: json['has_more'] as bool,
    latestID: json['latest_id'] as int,
    readID: json['read_id'] as int,
    partnerReadID: json['partner_read_id'] as int,
    unreadCount: json['unread_count'] as int,
  );

  final List<ChatMessage> messages;
  final bool hasMore;
  final int latestID;
  final int readID;
  final int partnerReadID;
  final int unreadCount;
}

/// Calls authenticated chat endpoints with bounded requests and no private logging.
class ChatApi {
  ChatApi(this.credentials, [http.Client? client])
    : _client = client ?? http.Client();

  final SavedPairingCredentials credentials;
  final http.Client _client;

  /// Releases the HTTP client when the couple space is closed.
  void close() => _client.close();

  /// Retrieves recent history, incremental messages, or an older history page.
  Future<ChatSnapshot> messages({int afterID = 0, int beforeID = 0}) async {
    final uri =
        PairingApi.resolveEndpoint(
          PairingApi.parseServerURL(credentials.serverURL),
          '/api/v1/chat/messages',
        ).replace(
          queryParameters: {
            if (afterID > 0) 'after_id': '$afterID',
            if (beforeID > 0) 'before_id': '$beforeID',
            'limit': '50',
          },
        );
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));
    return ChatSnapshot.fromJson(_decode(response));
  }

  /// Sends text with a stable client id so a lost response can be safely retried.
  Future<ChatMessage> send(String clientID, String text) async =>
      ChatMessage.fromJson(
        await _post('/messages', {'client_id': clientID, 'text': text}),
      );

  /// Advances this member's read cursor; receipts are shared across devices.
  Future<int> markRead(int messageID) async =>
      (await _post('/read', {'message_id': messageID}))['read_id'] as int;

  Map<String, String> get _headers => {
    'authorization': 'Bearer ${credentials.accessToken}',
    'content-type': 'application/json',
  };

  /// Sends a JSON request without placing message text or credentials in a URL.
  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client
        .post(
          PairingApi.resolveEndpoint(
            PairingApi.parseServerURL(credentials.serverURL),
            '/api/v1/chat$path',
          ),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    return _decode(response);
  }

  /// Retains HTTP status so revoked devices return to the existing session gate.
  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode != 200) {
      throw PairingApiException(
        'Could not synchronize messages (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }
}
