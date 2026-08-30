import 'dart:convert';

import 'package:http/http.dart' as http;

/// A one-time invitation returned by the Pawmate instance.
class PairingInvite {
  const PairingInvite({
    required this.expiresAt,
    required this.inviteURL,
    required this.inviterToken,
  });

  /// Decodes the server's invitation response.
  factory PairingInvite.fromJson(Map<String, dynamic> json) {
    return PairingInvite(
      expiresAt: DateTime.parse(json['expires_at'] as String),
      inviteURL: json['invite_url'] as String,
      inviterToken: json['inviter_token'] as String,
    );
  }

  final DateTime expiresAt;
  final String inviteURL;
  final String inviterToken;
}

/// Describes the pairing state observed by the inviting device.
class PairingStatus {
  const PairingStatus({required this.status, this.pairID});

  /// Decodes a pairing status response.
  factory PairingStatus.fromJson(Map<String, dynamic> json) {
    return PairingStatus(
      pairID: json['pair_id'] as String?,
      status: json['status'] as String,
    );
  }

  final String? pairID;
  final String status;
}

/// Represents a user-facing error returned while calling the pairing API.
class PairingApiException implements Exception {
  const PairingApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Calls the instance pairing endpoints for the inviting device.
class PairingApi {
  PairingApi([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  /// Releases the underlying HTTP client.
  void close() => _client.close();

  /// Creates an invitation on the configured server instance.
  Future<PairingInvite> createInvite(String rawServerURL) async {
    final serverURL = _parseServerURL(rawServerURL);
    final response = await _client
        .post(
          serverURL.resolve('/api/v1/pairing/invites'),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({'server_url': serverURL.toString()}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 201) {
      throw PairingApiException(_messageFor(response));
    }
    return PairingInvite.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Fetches the invitation state using the inviter's bearer token.
  Future<PairingStatus> getStatus(
    String rawServerURL,
    String inviterToken,
  ) async {
    final serverURL = _parseServerURL(rawServerURL);
    final response = await _client
        .get(
          serverURL.resolve('/api/v1/pairing/invites/status'),
          headers: {'authorization': 'Bearer $inviterToken'},
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw PairingApiException(_messageFor(response));
    }
    return PairingStatus.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Validates and normalizes a server URL before making a request.
  Uri _parseServerURL(String rawServerURL) {
    final uri = Uri.tryParse(rawServerURL.trim());
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const PairingApiException(
        'Use an http:// or https:// server URL without credentials or query parameters.',
      );
    }
    return uri.replace(path: uri.path.replaceFirst(RegExp(r'/+$'), ''));
  }

  /// Extracts a safe error message from a JSON API response.
  String _messageFor(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['error'] as String? ?? 'The server rejected the request.';
    } on Object {
      return 'The server rejected the request (${response.statusCode}).';
    }
  }
}
