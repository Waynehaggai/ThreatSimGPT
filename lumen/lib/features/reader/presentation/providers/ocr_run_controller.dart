import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/parsers/ocr_content_builder.dart';
import '../../../../domain/entities/book_content.dart';
import '../../../../domain/services/ocr_service.dart';

enum OcrStatus { idle, running, done, error }

/// Progress + results of an OCR run over one document.
class OcrRunState {
  const OcrRunState({
    this.status = OcrStatus.idle,
    this.pagesDone = 0,
    this.totalPages,
    this.results = const [],
    this.error,
  });

  final OcrStatus status;
  final int pagesDone;
  final int? totalPages;
  final List<OcrPageResult> results;
  final String? error;

  double? get fraction =>
      (totalPages != null && totalPages! > 0) ? pagesDone / totalPages! : null;

  OcrRunState copyWith({
    OcrStatus? status,
    int? pagesDone,
    int? totalPages,
    List<OcrPageResult>? results,
    String? error,
  }) =>
      OcrRunState(
        status: status ?? this.status,
        pagesDone: pagesDone ?? this.pagesDone,
        totalPages: totalPages ?? this.totalPages,
        results: results ?? this.results,
        error: error ?? this.error,
      );
}

/// Runs [OcrService.recognizeDocument] and aggregates streamed page results into
/// observable progress. Plain and framework-light so it is unit-testable with a
/// fake [OcrService]; the UI binds via `ValueListenableBuilder`.
class OcrRunController {
  OcrRunController(this._ocr);

  final OcrService _ocr;
  final ValueNotifier<OcrRunState> state = ValueNotifier(const OcrRunState());
  StreamSubscription<OcrPageResult>? _sub;

  Future<void> run(String filePath, {int? totalPages}) async {
    await _sub?.cancel();
    state.value = OcrRunState(status: OcrStatus.running, totalPages: totalPages);
    final results = <OcrPageResult>[];
    final completer = Completer<void>();

    _sub = _ocr.recognizeDocument(filePath).listen(
      (page) {
        results.add(page);
        state.value = state.value.copyWith(
          pagesDone: results.length,
          results: List.unmodifiable(results),
        );
      },
      onError: (Object e) {
        state.value = state.value.copyWith(status: OcrStatus.error, error: '$e');
        if (!completer.isCompleted) completer.complete();
      },
      onDone: () {
        state.value = state.value.copyWith(status: OcrStatus.done);
        if (!completer.isCompleted) completer.complete();
      },
    );
    return completer.future;
  }

  /// Builds Smart content from the (possibly user-corrected) [results].
  BookContent buildContent(String bookId, {List<OcrPageResult>? corrected}) =>
      buildOcrContent(bookId, corrected ?? state.value.results);

  Future<void> cancel() => _sub?.cancel() ?? Future.value();

  void dispose() {
    _sub?.cancel();
    state.dispose();
  }
}
