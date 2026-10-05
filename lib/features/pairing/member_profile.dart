import 'dart:convert';
import 'dart:typed_data';

/// A server-owned member identity that is shared by all of their devices.
class MemberProfile {
  const MemberProfile({required this.nickname, required this.avatar});

  final String nickname;
  final Uint8List avatar;

  /// Decodes a bounded portrait returned by the authenticated instance.
  factory MemberProfile.fromJson(Map<String, dynamic> json) => MemberProfile(
    nickname: json['nickname'] as String,
    avatar: base64Decode(json['avatar_base64'] as String),
  );

  /// Encodes identity alongside the invitation request, never in the link URL.
  Map<String, String> toJson() => {
    'nickname': nickname,
    'avatar_base64': base64Encode(avatar),
  };
}
