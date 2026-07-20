import '../../core/error/failures.dart';
import '../../core/result/result.dart';
import '../entities/book_content.dart';

/// A dictionary/definition lookup result.
class Definition {
  const Definition({required this.word, required this.meanings, this.phonetic});
  final String word;
  final String? phonetic;
  final List<String> meanings;
}

/// A generated study flashcard.
class Flashcard {
  const Flashcard({required this.front, required this.back});
  final String front;
  final String back;
}

/// Future-ready contract for AI-assisted reading features.
///
/// This interface is intentionally defined now and left unimplemented (a no-op
/// stub ships by default). It lets AI capabilities be plugged in later —
/// on-device, cloud, or via the Anthropic API — without any change to the core
/// reading architecture. Each method maps to a roadmap capability.
abstract interface class AiService {
  /// Whether AI features are currently available (feature flag / entitlement).
  bool get isEnabled;

  Future<Result<String>> summarizeChapter(Chapter chapter);
  Future<Result<String>> explainPassage(String passage, {String? context});
  Future<Result<Definition>> defineWord(String word, {String? sentence});
  Future<Result<String>> translate(String text, {required String targetLang});
  Future<Result<String>> answerQuestion(
    String question, {
    required String bookId,
  });

  /// Grounded Q&A: answers [question] using only the retrieved [passages]
  /// (classic RAG). Callers pass the passages a retriever selected from the
  /// book so the model stays anchored to the source text.
  Future<Result<String>> answerAboutBook(
    String question, {
    required List<String> passages,
  });

  Future<Result<List<Flashcard>>> generateFlashcards(Chapter chapter);
}

/// Default no-op implementation so the app runs without any AI backend wired.
/// Replace via DI when an AI provider is configured.
class DisabledAiService implements AiService {
  const DisabledAiService();

  @override
  bool get isEnabled => false;

  // NB: not `const` — a const expression can't use the method's type
  // parameter `T`, so the Result is constructed at runtime (the Failure
  // itself is still const).
  Result<T> _off<T>() => Result.failure(
        const UnexpectedFailure('AI features are not enabled in this build.'),
      );

  @override
  Future<Result<String>> summarizeChapter(Chapter chapter) async => _off();
  @override
  Future<Result<String>> explainPassage(
    String passage, {
    String? context,
  }) async =>
      _off();
  @override
  Future<Result<Definition>> defineWord(
    String word, {
    String? sentence,
  }) async =>
      _off();
  @override
  Future<Result<String>> translate(
    String text, {
    required String targetLang,
  }) async =>
      _off();
  @override
  Future<Result<String>> answerQuestion(
    String question, {
    required String bookId,
  }) async =>
      _off();
  @override
  Future<Result<String>> answerAboutBook(
    String question, {
    required List<String> passages,
  }) async =>
      _off();
  @override
  Future<Result<List<Flashcard>>> generateFlashcards(Chapter chapter) async =>
      _off();
}
