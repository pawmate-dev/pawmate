import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A one-time invitation returned by the Pawmate instance.
class PairingInvite {
  const PairingInvite({
    required this.expiresAt,
    required this.inviteURL,
    required this.inviterToken,
    required this.recoveryCode,
  });

  /// Decodes the server's invitation response.
  factory PairingInvite.fromJson(Map<String, dynamic> json) {
    return PairingInvite(
      expiresAt: DateTime.parse(json['expires_at'] as String),
      inviteURL: json['invite_url'] as String,
      inviterToken: json['inviter_token'] as String,
      recoveryCode: json['recovery_code'] as String,
    );
  }

  final DateTime expiresAt;
  final String inviteURL;
  final String inviterToken;
  final String recoveryCode;
}

/// Describes the pairing state observed by the inviting device.
class PairingStatus {
  const PairingStatus({
    required this.status,
    this.pairID,
    this.inviteeToken,
    this.recoveryCode,
  });

  /// Decodes a pairing status response.
  factory PairingStatus.fromJson(Map<String, dynamic> json) {
    return PairingStatus(
      pairID: json['pair_id'] as String?,
      status: json['status'] as String,
      inviteeToken: json['invitee_token'] as String?,
      recoveryCode: json['recovery_code'] as String?,
    );
  }

  final String? pairID;
  final String status;
  final String? inviteeToken;
  final String? recoveryCode;
}

/// Credentials issued when a member restores access with a recovery code.
class RecoveredCredentials {
  const RecoveredCredentials({
    required this.accessToken,
    required this.pairID,
    required this.recoveryCode,
    required this.role,
  });

  factory RecoveredCredentials.fromJson(Map<String, dynamic> json) {
    return RecoveredCredentials(
      accessToken: json['access_token'] as String,
      pairID: json['pair_id'] as String,
      recoveryCode: json['recovery_code'] as String,
      role: json['role'] as String,
    );
  }

  final String accessToken;
  final String pairID;
  final String recoveryCode;
  final String role;
}

/// Represents the authenticated member's server-side pairing session.
class PairingSession {
  const PairingSession({required this.role, required this.status, this.pairID});

  factory PairingSession.fromJson(Map<String, dynamic> json) {
    return PairingSession(
      pairID: json['pair_id'] as String?,
      role: json['role'] as String,
      status: json['status'] as String,
    );
  }

  final String? pairID;
  final String role;
  final String status;
}

/// Represents a user-facing error returned while calling the pairing API.
class PairingApiException implements Exception {
  const PairingApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

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
      throw PairingApiException(
        _messageFor(response),
        statusCode: response.statusCode,
      );
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
      throw PairingApiException(
        _messageFor(response),
        statusCode: response.statusCode,
      );
    }
    return PairingStatus.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Validates an access token and returns the member's current pairing state.
  Future<PairingSession> validateSession(
    String rawServerURL,
    String accessToken,
  ) async {
    final serverURL = _parseServerURL(rawServerURL);
    final response = await _client
        .get(
          serverURL.resolve('/api/v1/pairing/session'),
          headers: {'authorization': 'Bearer $accessToken'},
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw PairingApiException(
        _messageFor(response),
        statusCode: response.statusCode,
      );
    }
    return PairingSession.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Redeems a one-time invite code on the server encoded in the invite link.
  Future<PairingStatus> redeemInvite(String rawServerURL, String code) async {
    final serverURL = _parseServerURL(rawServerURL);
    final response = await _client
        .post(
          serverURL.resolve('/api/v1/pairing/invites/redeem'),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({'code': code}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw PairingApiException(
        _messageFor(response),
        statusCode: response.statusCode,
      );
    }
    return PairingStatus.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Rotates credentials using a member's single-use recovery code.
  Future<RecoveredCredentials> recover(
    String rawServerURL,
    String recoveryCode,
  ) async {
    final serverURL = _parseServerURL(rawServerURL);
    final response = await _client
        .post(
          serverURL.resolve('/api/v1/pairing/recover'),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({'recovery_code': recoveryCode.trim()}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw PairingApiException(
        _messageFor(response),
        statusCode: response.statusCode,
      );
    }
    return RecoveredCredentials.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Validates and normalizes a server URL before making a request.
  Uri _parseServerURL(String rawServerURL) {
    final uri = Uri.tryParse(rawServerURL.trim());
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        (uri.scheme == 'http' && !kDebugMode) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const PairingApiException(
        'Use an HTTPS server URL in release builds. HTTP is allowed only in debug builds.',
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
