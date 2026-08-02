import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// Original Mode: renders the authored PDF exactly as designed (engineering
/// drawings, tables, forms, academic papers) using the native `pdfrx` engine.
///
/// Reports page changes as a 0–1 progress fraction via [onProgress] so the
/// bottom bar, resume point and library tile stay in sync with Smart Mode.
///
/// NB: `pdfrx` is a native plugin — this view is exercised on a device/emulator,
/// not in the pure-Dart test suite. The exact params surface can vary slightly
/// between pdfrx minor versions; this targets the ^1.0 API.
class OriginalReaderView extends StatefulWidget {
  const OriginalReaderView({
    required this.filePath,
    required this.initialPercent,
    required this.onProgress,
    super.key,
  });

  final String filePath;
  final double initialPercent;

  /// Emits (percent, pageNumber, pageCount) as the user navigates.
  final void Function(double percent, int page, int pageCount) onProgress;

  @override
  State<OriginalReaderView> createState() => _OriginalReaderViewState();
}

class _OriginalReaderViewState extends State<OriginalReaderView> {
  final _controller = PdfViewerController();

  @override
  Widget build(BuildContext context) {
    if (!File(widget.filePath).existsSync()) {
      return const Center(child: Text('Original file not found.'));
    }
    return PdfViewer.file(
      widget.filePath,
      controller: _controller,
      params: PdfViewerParams(
        onViewerReady: (document, controller) {
          final target = (widget.initialPercent * document.pages.length)
              .round()
              .clamp(1, document.pages.length);
          controller.goToPage(pageNumber: target);
        },
        onPageChanged: (pageNumber) {
          final count = _controller.pageCount;
          if (pageNumber == null || count <= 0) return;
          widget.onProgress(pageNumber / count, pageNumber, count);
        },
      ),
    );
  }
}
