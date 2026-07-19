import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../data/parsers/ocr_content_builder.dart';
import '../../../../domain/services/ocr_service.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../providers/ocr_providers.dart';
import '../providers/ocr_run_controller.dart';
import '../providers/reader_providers.dart';

/// Runs OCR on a scanned book, shows progress, and lets the user correct the
/// recognised text page-by-page before it becomes Smart Reading content.
class OcrReviewScreen extends ConsumerStatefulWidget {
  const OcrReviewScreen({required this.bookId, super.key});

  final String bookId;

  @override
  ConsumerState<OcrReviewScreen> createState() => _OcrReviewScreenState();
}

class _OcrReviewScreenState extends ConsumerState<OcrReviewScreen> {
  final Map<int, TextEditingController> _editors = {};
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (_started) return;
    _started = true;
    try {
      final book = await ref.read(readerBookProvider(widget.bookId).future);
      await ref
          .read(ocrRunControllerProvider(widget.bookId))
          .run(book.filePath, totalPages: book.pageCount);
    } on Object {
      // Errors surface via the controller's error state.
    }
  }

  TextEditingController _editorFor(OcrPageResult page) =>
      _editors.putIfAbsent(page.pageIndex,
          () => TextEditingController(text: page.text));

  Future<void> _save(List<OcrPageResult> pages) async {
    final corrected = [
      for (final p in pages)
        OcrPageResult(
          pageIndex: p.pageIndex,
          text: _editors[p.pageIndex]?.text ?? p.text,
          confidence: 1.0, // user-verified
        ),
    ];
    final content = buildOcrContent(widget.bookId, corrected);
    ref.read(ocrContentProvider(widget.bookId).notifier).state = content;

    // Mark the book readable so it no longer prompts for OCR.
    final repo = ref.read(libraryRepositoryProvider);
    final book = (await repo.getBook(widget.bookId)).valueOrNull;
    if (book != null) {
      await repo.updateBook(
          book.copyWith(needsOcr: false, hasSmartContent: true));
    }
    if (mounted) context.pop();
  }

  @override
  void dispose() {
    for (final c in _editors.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(ocrRunControllerProvider(widget.bookId));
    return Scaffold(
      appBar: AppBar(title: const Text('Make readable (OCR)')),
      body: ValueListenableBuilder<OcrRunState>(
        valueListenable: controller.state,
        builder: (context, state, _) {
          final lowPages = lowConfidencePages(state.results);
          return Column(
            children: [
              if (state.status == OcrStatus.running)
                LinearProgressIndicator(value: state.fraction),
              if (state.status == OcrStatus.error)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('OCR failed: ${state.error}',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        state.status == OcrStatus.done
                            ? 'Recognised ${state.results.length} pages. Review and correct below.'
                            : 'Recognising… ${state.pagesDone}'
                                '${state.totalPages != null ? ' / ${state.totalPages}' : ''}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.results.length,
                  itemBuilder: (context, i) {
                    final page = state.results[i];
                    final low = lowPages.contains(page.pageIndex);
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('Page ${page.pageIndex + 1}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge),
                                const SizedBox(width: 8),
                                if (low)
                                  const Icon(Icons.warning_amber_rounded,
                                      size: 16),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _editorFor(page),
                              maxLines: null,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: ValueListenableBuilder<OcrRunState>(
        valueListenable: controller.state,
        builder: (context, state, _) => state.status == OcrStatus.done
            ? FloatingActionButton.extended(
                onPressed: () => _save(state.results),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Save & read'),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
