import 'dart:typed_data';

Future<void> downloadFileBytes(
  Uint8List bytes, {
  required String fileName,
  required String mimeType,
}) async {
  throw UnsupportedError('Browser download is only available on web.');
}

String? createObjectUrlFromBytes(
  Uint8List bytes, {
  required String mimeType,
}) {
  return null;
}

void revokeObjectUrl(String? objectUrl) {}
