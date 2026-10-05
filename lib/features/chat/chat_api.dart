import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../pairing/pairing_api.dart';
import '../pairing/pairing_credentials.dart';

/// Metadata exchanged with history; binary content travels separately with authentication.
class ChatAttachment {
  const ChatAttachment({
    required this.messageID,
    required this.kind,
    required this.name,
    required this.contentType,
    required this.size,
    required this.digest,
  });
  static const maxBytes = 20 * 1024 * 1024;
  final int messageID;
  final String kind;
  final String name;
  final String contentType;
  final int size;
  final String digest;
  factory ChatAttachment.fromJson(Map<String, dynamic> value) {
    final attachment = ChatAttachment(
      messageID: value['message_id'] as int,
      kind: value['kind'] as String,
      name: value['name'] as String,
      contentType: value['content_type'] as String,
      size: value['size'] as int,
      digest: value['sha256'] as String,
    );
    if (attachment.messageID < 0 ||
        !['file', 'image'].contains(attachment.kind) ||
        attachment.size <= 0 ||
        attachment.size > maxBytes ||
        attachment.name.isEmpty ||
        attachment.name == '.' ||
        attachment.name == '..' ||
        utf8.encode(attachment.name).length > 255 ||
        attachment.name.contains(RegExp(r'[/\\\x00-\x1f\x7f-\x9f]')) ||
        (attachment.kind == 'file' &&
            attachment.contentType != 'application/octet-stream') ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(attachment.digest) ||
        (attachment.kind == 'image' &&
            ![
              'image/png',
              'image/jpeg',
              'image/gif',
            ].contains(attachment.contentType))) {
      throw const FormatException('Invalid attachment metadata');
    }
    return attachment;
  }
  Map<String, dynamic> toJson() => {
    'message_id': messageID,
    'kind': kind,
    'name': name,
    'content_type': contentType,
    'size': size,
    'sha256': digest,
  };
}

/// Private bytes and immutable metadata retained for offline uploads and retries.
class AttachmentUpload {
  const AttachmentUpload(this.metadata, this.bytes);
  final ChatAttachment metadata;
  final Uint8List bytes;
}

/// A text message whose identity and order are assigned by the private server.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.clientID,
    required this.sender,
    required this.text,
    required this.createdAt,
    this.serverConfirmed = true,
    this.attachment,
  });

  /// Decodes a persisted message, including messages from this member's other devices.
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final message = ChatMessage(
      id: json['id'] as int,
      clientID: json['client_id'] as String,
      sender: json['sender'] as String,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      attachment: json['attachment'] == null
          ? null
          : ChatAttachment.fromJson(json['attachment'] as Map<String, dynamic>),
    );
    if (message.attachment != null &&
        (message.id <= 0 || message.attachment!.messageID != message.id)) {
      throw const FormatException('Attachment message identity mismatch');
    }
    return message;
  }

  final int id;
  final String clientID;
  final String sender;
  final String text;
  final DateTime createdAt;
  final ChatAttachment? attachment;

  /// Imported device history remains local-only until corroborated by the server.
  final bool serverConfirmed;

  /// Serializes message content only, never credentials or trusted sync metadata.
  Map<String, dynamic> toJson() => {
    'id': id,
    'client_id': clientID,
    'sender': sender,
    'text': text,
    'created_at': createdAt.toUtc().toIso8601String(),
    if (attachment != null) 'attachment': attachment!.toJson(),
  };
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

  /// Streams a bounded multipart request with a stable retry identity, never a public URL.
  Future<ChatMessage> sendAttachment(
    String clientID,
    AttachmentUpload upload,
  ) async {
    final request =
        http.MultipartRequest(
            'POST',
            PairingApi.resolveEndpoint(
              PairingApi.parseServerURL(credentials.serverURL),
              '/api/v1/chat/attachments',
            ),
          )
          ..headers['authorization'] = 'Bearer ${credentials.accessToken}'
          ..fields.addAll({'client_id': clientID, 'kind': upload.metadata.kind})
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              upload.bytes,
              filename: upload.metadata.name,
            ),
          );
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 90));
    return ChatMessage.fromJson(
      _decode(
        await http.Response.fromStream(
          response,
        ).timeout(const Duration(seconds: 90)),
      ),
    );
  }

  /// Bounds streamed downloads and verifies content identity before caching or opening.
  Future<Uint8List> downloadAttachment(ChatAttachment attachment) async {
    final request = http.Request(
      'GET',
      PairingApi.resolveEndpoint(
        PairingApi.parseServerURL(credentials.serverURL),
        '/api/v1/chat/attachments/${attachment.messageID}',
      ),
    )..headers.addAll(_headers);
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      await response.stream.drain<void>().timeout(const Duration(seconds: 30));
      throw PairingApiException(
        'Attachment unavailable',
        statusCode: response.statusCode,
      );
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 30),
    )) {
      if (bytes.length + chunk.length > attachment.size ||
          bytes.length + chunk.length > ChatAttachment.maxBytes) {
        throw const FormatException('Attachment size mismatch');
      }
      bytes.add(chunk);
    }
    final result = bytes.takeBytes();
    if (result.length != attachment.size ||
        sha256.convert(result).toString() != attachment.digest) {
      throw const FormatException('Attachment integrity mismatch');
    }
    return result;
  }

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
