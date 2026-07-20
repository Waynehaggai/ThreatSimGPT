import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/error/failures.dart';
import '../../core/result/result.dart';
import '../../domain/entities/book_content.dart';
import '../../domain/services/ai_service.dart';

/// Configuration for the Claude-backed AI module.
///
/// ## Security — never ship an API key in the app
/// A mobile app is an untrusted client; an embedded `x-api-key` can be extracted
/// from the binary. In production, [baseUrl] MUST point at **your own backend
/// proxy**, which holds the Anthropic key server‑side and forwards to
/// `https://api.anthropic.com`. The proxy is also where you enforce
/// per‑user rate limits, auth, and spend caps. [apiKey] is provided only for
/// local development/testing against the API directly and should stay null in
/// released builds.
class AiConfig {
  const AiConfig({
    required this.baseUrl,
    this.apiKey,
    this.model = 'claude-opus-4-8',
    this.enabled = true,
  });

  /// Your backend proxy base URL (e.g. `https://api.yourapp.com/ai`). The
  /// service POSTs to `$baseUrl/v1/messages`.
  final String baseUrl;

  /// Dev-only direct key. Leave null in production (the proxy injects it).
  final String? apiKey;

  /// Anthropic model id. Defaults to the latest, most capable Claude model.
  final String model;

  final bool enabled;
}

/// Claude-backed implementation of [AiService] (the future AI module).
///
/// Dart has no official Anthropic SDK, so this calls the Messages API over raw
/// HTTP (`POST /v1/messages`) through [http.Client] — injected so request
/// construction and response parsing are unit-testable with a mock client.
///
/// Model: `claude-opus-4-8`. Structured tasks (dictionary, flashcards) use the
/// Messages API structured-output format for reliable JSON; prose tasks
/// (summaries, explanations, translation, Q&A) return text.
class AnthropicAiService implements AiService {
  AnthropicAiService(this._config, {http.Client? client})
      : _client = client ?? http.Client();

  final AiConfig _config;
  final http.Client _client;

  static const _anthropicVersion = '2023-06-01';

  @override
  bool get isEnabled => _config.enabled;

  @override
  Future<Result<String>> summarizeChapter(Chapter chapter) {
    return _text(
      system: 'You are a reading companion. Summarize the given book chapter '
          'in 4–6 clear sentences, capturing the key events and ideas. Do not '
          'add information that is not in the text.',
      user: 'Chapter: ${chapter.title}\n\n${_chapterText(chapter)}',
      maxTokens: 1024,
    );
  }

  @override
  Future<Result<String>> explainPassage(String passage, {String? context}) {
    return _text(
      system: 'You explain difficult passages for a reader. Give a clear, '
          'concise explanation in plain language. Keep it under 150 words.',
      user: [
        if (context != null && context.isNotEmpty) 'Context: $context\n',
        'Passage:\n$passage',
      ].join(),
      maxTokens: 512,
    );
  }

  @override
  Future<Result<String>> translate(String text, {required String targetLang}) {
    return _text(
      system: 'You are a translator. Translate the user text into $targetLang. '
          'Respond with only the translation, no notes.',
      user: text,
      maxTokens: 1024,
      think: false,
    );
  }

  @override
  Future<Result<String>> answerQuestion(String question, {required String bookId}) {
    // Production RAG injects retrieved book passages into the system prompt;
    // here the question is answered directly (see docs/AI_MODULE.md).
    return _text(
      system: 'You answer a reader\'s question about the book they are reading. '
          'Be accurate and concise. If you are unsure, say so.',
      user: question,
      maxTokens: 1024,
    );
  }

  @override
  Future<Result<String>> answerAboutBook(
    String question, {
    required List<String> passages,
  }) {
    if (passages.isEmpty) {
      return answerQuestion(question, bookId: '');
    }
    // RAG: ground the answer in the retrieved passages. The passages are
    // numbered so the model can be told to rely on them and to admit when the
    // answer isn't present, reducing hallucination.
    final context = <String>[
      for (var i = 0; i < passages.length; i++)
        '[${i + 1}] ${passages[i].trim()}',
    ].join('\n\n');
    return _text(
      system: 'You answer a reader\'s question about the book they are reading. '
          'Use ONLY the numbered passages provided as context. If the passages '
          'do not contain the answer, say you could not find it in the book '
          'rather than guessing. Be accurate and concise.',
      user: 'Context passages from the book:\n\n$context\n\n'
          'Question: $question',
      maxTokens: 1024,
    );
  }

  @override
  Future<Result<Definition>> defineWord(String word, {String? sentence}) async {
    final result = await _json(
      system: 'You are a dictionary. Define the given word as used in the '
          'provided sentence when present. Return concise meanings.',
      user: [
        'Word: $word',
        if (sentence != null && sentence.isNotEmpty) 'Sentence: $sentence',
      ].join('\n'),
      maxTokens: 512,
      schema: const {
        'type': 'object',
        'properties': {
          'word': {'type': 'string'},
          'phonetic': {'type': 'string'},
          'meanings': {
            'type': 'array',
            'items': {'type': 'string'},
          },
        },
        'required': ['word', 'meanings'],
        'additionalProperties': false,
      },
    );
    return result.map((json) => Definition(
          word: '${json['word'] ?? word}',
          phonetic: json['phonetic'] as String?,
          meanings: ((json['meanings'] as List?) ?? const [])
              .map((m) => '$m')
              .toList(),
        ));
  }

  @override
  Future<Result<List<Flashcard>>> generateFlashcards(Chapter chapter) async {
    final result = await _json(
      system: 'You create study flashcards from a book chapter. Produce 5–8 '
          'question/answer cards covering the most important points.',
      user: 'Chapter: ${chapter.title}\n\n${_chapterText(chapter)}',
      maxTokens: 2048,
      schema: const {
        'type': 'object',
        'properties': {
          'cards': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'front': {'type': 'string'},
                'back': {'type': 'string'},
              },
              'required': ['front', 'back'],
              'additionalProperties': false,
            },
          },
        },
        'required': ['cards'],
        'additionalProperties': false,
      },
    );
    return result.map((json) => ((json['cards'] as List?) ?? const [])
        .map((c) => Flashcard(
              front: '${(c as Map)['front'] ?? ''}',
              back: '${c['back'] ?? ''}',
            ))
        .toList());
  }

  // ── request helpers ────────────────────────────────────────────────────

  /// A prose (text-returning) Messages request.
  Future<Result<String>> _text({
    required String system,
    required String user,
    required int maxTokens,
    bool think = true,
  }) async {
    final body = <String, dynamic>{
      'model': _config.model,
      'max_tokens': maxTokens,
      'system': system,
      'messages': [
        {'role': 'user', 'content': user},
      ],
      if (think) 'thinking': const {'type': 'adaptive'},
      if (think) 'output_config': const {'effort': 'medium'},
    };
    final result = await _post(body);
    return result.map(_firstText);
  }

  /// A structured (JSON-returning) Messages request using output_config.format.
  Future<Result<Map<String, dynamic>>> _json({
    required String system,
    required String user,
    required int maxTokens,
    required Map<String, dynamic> schema,
  }) async {
    final body = <String, dynamic>{
      'model': _config.model,
      'max_tokens': maxTokens,
      'system': system,
      'messages': [
        {'role': 'user', 'content': user},
      ],
      'output_config': {
        'format': {'type': 'json_schema', 'schema': schema},
      },
    };
    final result = await _post(body);
    return result.fold<Result<Map<String, dynamic>>>(
      onFailure: (f) => Result.failure(f),
      onSuccess: (json) {
        try {
          return Result.success(
              jsonDecode(_firstText(json)) as Map<String, dynamic>);
        } on Object catch (e) {
          return Result.failure(
              UnexpectedFailure('AI returned malformed JSON.', cause: e));
        }
      },
    );
  }

  Future<Result<Map<String, dynamic>>> _post(Map<String, dynamic> body) async {
    if (!_config.enabled) {
      return const Result.failure(UnexpectedFailure('AI features are disabled.'));
    }
    try {
      final response = await _client.post(
        Uri.parse('${_config.baseUrl}/v1/messages'),
        headers: {
          'content-type': 'application/json',
          'anthropic-version': _anthropicVersion,
          if (_config.apiKey != null) 'x-api-key': _config.apiKey!,
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        return Result.failure(
            NetworkFailure('AI request failed (${response.statusCode}).'));
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['stop_reason'] == 'refusal') {
        return const Result.failure(
            UnexpectedFailure('The AI declined this request.'));
      }
      return Result.success(json);
    } on Object catch (e) {
      return Result.failure(NetworkFailure('Could not reach the AI service.',
          cause: e));
    }
  }

  /// Extracts the first text block from a Messages API response.
  String _firstText(Map<String, dynamic> json) {
    final content = (json['content'] as List?) ?? const [];
    for (final block in content) {
      if (block is Map && block['type'] == 'text') {
        return '${block['text']}'.trim();
      }
    }
    return '';
  }

  String _chapterText(Chapter chapter) => chapter.blocks
      .map((b) => b.text)
      .where((t) => t != null && t.isNotEmpty)
      .join('\n\n');

  void dispose() => _client.close();
}
