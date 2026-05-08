import 'package:flutter/widgets.dart';

import 'pdf_preview_stub.dart'
    if (dart.library.html) 'pdf_preview_web.dart';

class PdfPreviewWidget extends StatelessWidget {
  const PdfPreviewWidget({super.key, required this.pdfUrl});

  final String pdfUrl;

  @override
  Widget build(BuildContext context) => buildPdfPreviewWidget(pdfUrl);
}

Future<void> downloadPdfFile(String pdfUrl) => downloadPdfWidget(pdfUrl);
