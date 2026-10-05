import 'dart:typed_data';

import 'attachment_export_stub.dart'
    if (dart.library.io) 'attachment_export_native.dart'
    as platform;

/// Saves only at an explicit user-selected destination; cancellation is not failure.
Future<bool> saveChatAttachment(
  String name,
  String contentType,
  Uint8List bytes,
) => platform.saveChatAttachment(name, contentType, bytes);
