import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';

import 'chat_api.dart';

typedef ChatAttachmentPicker =
    Future<AttachmentUpload?> Function(bool imageOnly, String imagesLabel);

/// Reads only an explicitly selected, bounded file; image dimensions are checked before preview.
Future<AttachmentUpload?> pickChatAttachment(
  bool imageOnly,
  String imagesLabel,
) async {
  final file = await openFile(
    acceptedTypeGroups: imageOnly
        ? [
            XTypeGroup(
              label: imagesLabel,
              extensions: const ['png', 'jpg', 'jpeg', 'gif'],
              mimeTypes: const ['image/png', 'image/jpeg', 'image/gif'],
              uniformTypeIdentifiers: const [
                'public.png',
                'public.jpeg',
                'com.compuserve.gif',
              ],
            ),
          ]
        : [],
  );
  if (file == null) return null;
  final length = await file.length();
  if (length <= 0 || length > ChatAttachment.maxBytes) {
    throw const FormatException('Invalid attachment size');
  }
  // Bound the actual read too: a selected file may change after the length check.
  final collected = BytesBuilder(copy: false);
  await for (final chunk in file.openRead()) {
    if (collected.length + chunk.length > ChatAttachment.maxBytes) {
      throw const FormatException('Invalid attachment size');
    }
    collected.add(chunk);
  }
  final bytes = collected.takeBytes();
  if (bytes.length != length) throw const FormatException('Attachment changed');
  var contentType = 'application/octet-stream';
  if (imageOnly) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47) {
      contentType = 'image/png';
    } else if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      contentType = 'image/jpeg';
    } else if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46) {
      contentType = 'image/gif';
    } else {
      throw const FormatException('Unsupported image');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        if (descriptor.width * descriptor.height > 25000000) {
          throw const FormatException('Image too large');
        }
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
  }
  final metadata = ChatAttachment.fromJson({
    'message_id': 0,
    'kind': imageOnly ? 'image' : 'file',
    'name': file.name,
    'content_type': contentType,
    'size': bytes.length,
    'sha256': sha256.convert(bytes).toString(),
  });
  return AttachmentUpload(metadata, bytes);
}
