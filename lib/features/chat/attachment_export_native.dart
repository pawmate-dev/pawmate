import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

/// Mobile document pickers and desktop save dialogs avoid broad storage permissions.
Future<bool> saveChatAttachment(
  String name,
  String contentType,
  Uint8List bytes,
) async {
  if (Platform.isAndroid || Platform.isIOS) {
    return await const MethodChannel(
          'dev.pawmate.app/attachments',
        ).invokeMethod<bool>('save', {
          'name': name,
          'content_type': contentType,
          'bytes': bytes,
        }) ??
        false;
  }
  final destination = await getSaveLocation(suggestedName: name);
  if (destination == null) return false;
  await XFile.fromData(
    bytes,
    name: name,
    mimeType: contentType,
  ).saveTo(destination.path);
  return true;
}
