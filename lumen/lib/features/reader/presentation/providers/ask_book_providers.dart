import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/repository_providers.dart';
import '../rendering/passage_retriever.dart';
import 'reader_providers.dart';

/// One turn in the Q&A conversation about a book.
class QaTurn {
  const QaTurn({
    required this.question,
    this.answer,
    this.error,
    this.pending = false,
  });

  final String question;
  final String? answer;
  final String? error;
  final bool pending;

  QaTurn copyWith({String? answer, String? error, bool? pending}) => QaTurn(
        question: question,
        answer: answer ?? this.answer,
        error: error ?? this.error,
        pending: pending ?? this.pending,
      );
}

/// Drives the "Ask about this book" panel: retrieves relevant passages from the
/// reflowed [BookContent] (RAG) and asks the AI to answer grounded in them.
class AskBookController extends FamilyNotifier<List<QaTurn>, String> {
  @override
  List<QaTurn> build(String bookId) => const <QaTurn>[];

  Future<void> ask(String question) async {
    final q = question.trim();
    if (q.isEmpty) return;

    // Append a pending turn.
    final index = state.length;
    state = [...state, QaTurn(question: q, pending: true)];

    // Retrieve grounding passages from the book content. Await the future so
    // retrieval works even when the Ask screen is opened before the reader has
    // cached the content; failures fall back to a passage-less answer.
    List<String> passages = const <String>[];
    try {
      final content = await ref.read(readerContentProvider(arg).future);
      passages = retrievePassages(content, q);
    } on Object {
      passages = const <String>[];
    }

    final result = await ref
        .read(aiServiceProvider)
        .answerAboutBook(q, passages: passages);

    final resolved = result.fold(
      onSuccess: (answer) =>
          QaTurn(question: q, answer: answer, pending: false),
      onFailure: (f) => QaTurn(question: q, error: f.message, pending: false),
    );

    // Replace the pending turn (guard against list changes).
    if (index < state.length) {
      final next = [...state];
      next[index] = resolved;
      state = next;
    }
  }

  void clear() => state = const <QaTurn>[];
}

final askBookControllerProvider =
    NotifierProvider.family<AskBookController, List<QaTurn>, String>(
  AskBookController.new,
);
