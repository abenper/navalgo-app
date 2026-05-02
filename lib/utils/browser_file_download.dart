import 'dart:typed_data';

import 'browser_file_download_stub.dart'
    if (dart.library.html) 'browser_file_download_web.dart' as impl;

Future<void> downloadFileBytes(
  Uint8List bytes, {
  required String fileName,
  required String mimeType,
}) {
  return impl.downloadFileBytes(
    bytes,
    fileName: fileName,
    mimeType: mimeType,
  );
}

String? createObjectUrlFromBytes(
  Uint8List bytes, {
  required String mimeType,
}) {
  return impl.createObjectUrlFromBytes(bytes, mimeType: mimeType);
}

void revokeObjectUrl(String? objectUrl) {
  impl.revokeObjectUrl(objectUrl);
}
