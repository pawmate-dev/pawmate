import 'dart:typed_data';

/// Web saving needs a separate browser adapter rather than a public download URL.
Future<bool> saveChatAttachment(
  String name,
  String contentType,
  Uint8List bytes,
) async => throw UnsupportedError(
  'Attachment export is not supported on this platform',
);
