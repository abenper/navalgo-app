import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<void> downloadFileBytes(
  Uint8List bytes, {
  required String fileName,
  required String mimeType,
}) async {
  final directory = await _resolveDownloadDirectory();
  final safeName = _safeFileName(fileName);
  final file = File('${directory.path}${Platform.pathSeparator}$safeName');
  await file.writeAsBytes(bytes, flush: true);
}

String? createObjectUrlFromBytes(
  Uint8List bytes, {
  required String mimeType,
}) {
  return null;
}

void revokeObjectUrl(String? objectUrl) {}

Future<Directory> _resolveDownloadDirectory() async {
  try {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      return downloads;
    }
  } catch (_) {
    // Some platforms expose downloads through the system UI but not path_provider.
  }
  return getApplicationDocumentsDirectory();
}

String _safeFileName(String fileName) {
  final trimmed = fileName.trim();
  final baseName = trimmed.isEmpty ? 'adjunto' : trimmed;
  return baseName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}
