import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'member_profile.dart';

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
  const PairingSession({
    required this.role,
    required this.status,
    this.pairID,
    this.profile,
    this.partner,
  });

  /// Caches identity and pairing status only; never includes authorization secrets.
  Map<String, dynamic> toJson() => {
    'role': role,
    'status': status,
    'pair_id': pairID,
    'profile': profile?.toJson(),
    'partner': partner?.toJson(),
  };

  factory PairingSession.fromJson(Map<String, dynamic> json) {
    return PairingSession(
      pairID: json['pair_id'] as String?,
      role: json['role'] as String,
      status: json['status'] as String,
      profile: json['profile'] == null
          ? null
          : MemberProfile.fromJson(json['profile'] as Map<String, dynamic>),
      partner: json['partner'] == null
          ? null
          : MemberProfile.fromJson(json['partner'] as Map<String, dynamic>),
    );
  }

  final String? pairID;
  final String role;
  final String status;
  final MemberProfile? profile;
  final MemberProfile? partner;
}

/// A short-lived code created by an already authenticated device.
class DeviceLoginCode {
  const DeviceLoginCode({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;
}

/// Credentials for an additional device; recovery secrets are not transferred.
class DeviceLoginCredentials {
  const DeviceLoginCredentials({
    required this.accessToken,
    required this.pairID,
    required this.role,
  });

  final String accessToken;
  final String pairID;
  final String role;
}

/// Public metadata for one of the authenticated member's devices.
class PairingDevice {
  const PairingDevice({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.current,
  });

  /// Decodes device metadata without access tokens or recovery codes.
  factory PairingDevice.fromJson(Map<String, dynamic> json) => PairingDevice(
    id: json['id'] as String,
    name: json['name'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    current: json['current'] as bool,
  );

  final String id;
  final String name;
  final DateTime createdAt;
  final bool current;
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

  /// Provides an editable display label without collecting a device identifier.
  static String get defaultDeviceName => kIsWeb
      ? 'Web browser'
      : switch (defaultTargetPlatform) {
          TargetPlatform.android => 'Android device',
          TargetPlatform.iOS => 'iOS device',
          TargetPlatform.macOS => 'Mac',
          TargetPlatform.windows => 'Windows computer',
          TargetPlatform.linux => 'Linux computer',
          TargetPlatform.fuchsia => 'Fuchsia device',
        };

  /// Releases the underlying HTTP client.
  void close() => _client.close();

  /// Creates an invitation on the configured server instance.
  Future<PairingInvite> createInvite(
    String rawServerURL, {
    required MemberProfile profile,
  }) async {
    final serverURL = _parseServerURL(rawServerURL);
    final response = await _client
        .post(
          resolveEndpoint(serverURL, '/api/v1/pairing/invites'),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({
            'server_url': serverURL.toString(),
            'profile': profile.toJson(),
            'device_name': defaultDeviceName,
          }),
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
          resolveEndpoint(serverURL, '/api/v1/pairing/invites/status'),
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
          resolveEndpoint(serverURL, '/api/v1/pairing/session'),
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
  Future<PairingStatus> redeemInvite(
    String rawServerURL,
    String code, {
    required MemberProfile profile,
  }) async {
    final serverURL = _parseServerURL(rawServerURL);
    final response = await _client
        .post(
          resolveEndpoint(serverURL, '/api/v1/pairing/invites/redeem'),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({
            'code': code,
            'device_name': defaultDeviceName,
            'profile': profile.toJson(),
          }),
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
          resolveEndpoint(serverURL, '/api/v1/pairing/recover'),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({
            'recovery_code': recoveryCode.trim(),
            'device_name': defaultDeviceName,
          }),
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

  /// Lists the member's devices, identifying the token used for this request.
  Future<List<PairingDevice>> getDevices(String server, String token) async {
    final response = await _client
        .get(
          resolveEndpoint(_parseServerURL(server), '/api/v1/pairing/devices'),
          headers: {'authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 10));
    final body = _deviceResponse(response, 200);
    return (body['devices'] as List<dynamic>)
        .map((item) => PairingDevice.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Issues a one-time login code while keeping all device sessions active.
  Future<DeviceLoginCode> createDeviceLoginCode(
    String server,
    String token,
  ) async {
    final response = await _client
        .post(
          resolveEndpoint(
            _parseServerURL(server),
            '/api/v1/pairing/devices/login-codes',
          ),
          headers: {'authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 10));
    final body = _deviceResponse(response, 201);
    return DeviceLoginCode(
      code: body['code'] as String,
      expiresAt: DateTime.parse(body['expires_at'] as String),
    );
  }

  /// Exchanges a code for this installation's independent access token.
  Future<DeviceLoginCredentials> redeemDeviceLoginCode(
    String server,
    String code,
    String deviceName,
  ) async {
    final response = await _client
        .post(
          resolveEndpoint(
            _parseServerURL(server),
            '/api/v1/pairing/devices/login-codes/redeem',
          ),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({
            'code': code.trim(),
            'device_name': deviceName.trim(),
          }),
        )
        .timeout(const Duration(seconds: 10));
    final body = _deviceResponse(response, 200);
    return DeviceLoginCredentials(
      accessToken: body['access_token'] as String,
      pairID: body['pair_id'] as String,
      role: body['role'] as String,
    );
  }

  /// Removes one device owned by this member, leaving other tokens active.
  Future<void> revokeDevice(String server, String token, String id) async {
    final response = await _client
        .delete(
          resolveEndpoint(
            _parseServerURL(server),
            '/api/v1/pairing/devices/${Uri.encodeComponent(id)}',
          ),
          headers: {'authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 204) {
      throw PairingApiException(
        _messageFor(response),
        statusCode: response.statusCode,
      );
    }
  }

  /// Checks a device endpoint's status before decoding its successful response.
  Map<String, dynamic> _deviceResponse(http.Response response, int status) {
    if (response.statusCode != status) {
      throw PairingApiException(
        _messageFor(response),
        statusCode: response.statusCode,
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Validates and normalizes HTTP or HTTPS instance URLs in every build mode.
  static Uri _parseServerURL(String rawServerURL) {
    final uri = Uri.tryParse(rawServerURL.trim());
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const PairingApiException(
        'Use an HTTP or HTTPS server URL without credentials, a query, or a fragment.',
      );
    }
    return uri.replace(path: uri.path.replaceFirst(RegExp(r'/+$'), ''));
  }

  /// Shares the instance URL policy with other authenticated feature clients.
  static Uri parseServerURL(String rawServerURL) =>
      _parseServerURL(rawServerURL);

  /// Resolves an API path under the configured instance prefix.
  static Uri resolveEndpoint(Uri serverURL, String endpointPath) {
    final basePath = serverURL.path.endsWith('/')
        ? serverURL.path
        : '${serverURL.path}/';
    final relativePath = endpointPath.replaceFirst(RegExp(r'^/+'), '');
    return serverURL.replace(path: basePath).resolve(relativePath);
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
