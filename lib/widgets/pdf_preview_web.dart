// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

Future<void> downloadPdfWidget(String pdfUrl) async {
  final anchor = html.AnchorElement(href: pdfUrl)
    ..download = ''
    ..target = 'blank';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}

Widget buildPdfPreviewWidget(String pdfUrl) {
  final viewType = 'pdf-preview-${DateTime.now().microsecondsSinceEpoch}-${pdfUrl.hashCode}';
  ui.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final iframe = html.IFrameElement()
      ..src = pdfUrl
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';
    return iframe;
  });
  return HtmlElementView(viewType: viewType);
}
