import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> downloadPdfWidget(String pdfUrl) async {
  final uri = Uri.tryParse(pdfUrl);
  if (uri == null) {
    return;
  }
  await launchUrl(uri);
}

Widget buildPdfPreviewWidget(String pdfUrl) {
  return Center(
    child: Text('Vista previa de PDF solo disponible en web.'),
  );
}
