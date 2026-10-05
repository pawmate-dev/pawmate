import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the current member credentials in the platform secure storage.
class PairingCredentials {
  PairingCredentials({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // This private client stores local Keychain items without cross-app sharing.
            // macOS therefore needs no Keychain Sharing provisioning profile.
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          );

  static const _storageKey = 'pawmate.pairing.credentials.v1';

  final FlutterSecureStorage _storage;

  /// Reads credentials saved by this installation, if any.
  Future<SavedPairingCredentials?> read() async {
    final value = await _storage.read(key: _storageKey);
    if (value == null) return null;
    return SavedPairingCredentials.fromJson(
      jsonDecode(value) as Map<String, dynamic>,
    );
  }

  /// Saves credentials issued for one member of the couple.
  Future<void> save({
    required String serverURL,
    required String accessToken,
    required String recoveryCode,
    required String pairID,
    required String role,
    String? inviteURL,
    DateTime? expiresAt,
  }) async {
    await _storage.write(
      key: _storageKey,
      value: jsonEncode({
        'server_url': serverURL,
        'access_token': accessToken,
        'recovery_code': recoveryCode,
        'pair_id': pairID,
        'role': role,
        'invite_url': ?inviteURL,
        'expires_at': ?expiresAt?.toIso8601String(),
      }),
    );
  }
}

/// Credentials retained locally for this app installation.
class SavedPairingCredentials {
  const SavedPairingCredentials({
    required this.serverURL,
    required this.accessToken,
    required this.recoveryCode,
    required this.pairID,
    required this.role,
    this.inviteURL,
    this.expiresAt,
  });

  factory SavedPairingCredentials.fromJson(Map<String, dynamic> json) {
    return SavedPairingCredentials(
      serverURL: json['server_url'] as String,
      accessToken: json['access_token'] as String,
      recoveryCode: json['recovery_code'] as String,
      pairID: json['pair_id'] as String,
      role: json['role'] as String,
      inviteURL: json['invite_url'] as String?,
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
    );
  }

  final String serverURL;
  final String accessToken;

  /// Empty on additional devices: device sign-in never transfers this secret.
  final String recoveryCode;
  final String pairID;
  final String role;
  final String? inviteURL;
  final DateTime? expiresAt;
}
