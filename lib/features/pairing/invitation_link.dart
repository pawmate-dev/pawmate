import 'pairing_api.dart';

/// Validates the same private invitation contract for pasted and external links.
abstract final class InvitationLink {
  /// Parses a complete one-time link without contacting or logging its server.
  static Uri parse(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'pawmate' ||
        uri.host != 'pair' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const FormatException(
        'Paste the complete pawmate://pair invitation link.',
      );
    }
    final values = uri.queryParametersAll;
    if (values['server']?.length != 1 ||
        values['code']?.length != 1 ||
        values['code']!.single.trim().isEmpty) {
      throw const FormatException(
        'This invitation needs one server address and one invitation code.',
      );
    }
    try {
      PairingApi.parseServerURL(values['server']!.single);
    } on PairingApiException {
      throw const FormatException(
        'The invitation contains an invalid server address.',
      );
    }
    return uri;
  }
}
