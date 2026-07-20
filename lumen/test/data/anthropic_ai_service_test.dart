import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumen/data/services/anthropic_ai_service.dart';
import 'package:lumen/domain/entities/book_content.dart';

/// A Messages API text response.
http.Response _text(String text) => http.Response(
      jsonEncode({
        'content': [
          {'type': 'text', 'text': text},
        ],
        'stop_reason': 'end_turn',
      }),
      200,
    );

const _chapter = Chapter(
  id: 'c0',
  title: 'Chapter One',
  order: 0,
  blocks: [
    ContentBlock(type: BlockType.paragraph, text: 'Once upon a time.'),
  ],
);

AnthropicAiService _service(MockClient client) => AnthropicAiService(
      const AiConfig(baseUrl: 'https://proxy.test'),
      client: client,
    );

void main() {
  test('summarizeChapter posts to the proxy with the default model', () async {
    late http.Request captured;
    final service = _service(MockClient((req) async {
      captured = req;
      return _text('A concise summary.');
    }));

    final result = await service.summarizeChapter(_chapter);

    expect(result.valueOrNull, 'A concise summary.');
    expect(captured.url.toString(), 'https://proxy.test/v1/messages');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['model'], 'claude-opus-4-8');
    expect(captured.headers['anthropic-version'], '2023-06-01');
    // No API key is sent from the client — the proxy injects it.
    expect(captured.headers.containsKey('x-api-key'), isFalse);
  });

  test('defineWord parses the structured JSON response', () async {
    final service = _service(MockClient((req) async {
      // Structured output: the text block contains JSON.
      return _text(jsonEncode({
        'word': 'lumen',
        'phonetic': 'ˈluːmən',
        'meanings': ['the SI unit of luminous flux'],
      }));
    }));

    final result = await service.defineWord('lumen');
    final def = result.valueOrNull!;
    expect(def.word, 'lumen');
    expect(def.phonetic, 'ˈluːmən');
    expect(def.meanings, hasLength(1));
  });

  test('generateFlashcards maps the cards array', () async {
    final service = _service(MockClient((req) async {
      return _text(jsonEncode({
        'cards': [
          {'front': 'Q1', 'back': 'A1'},
          {'front': 'Q2', 'back': 'A2'},
        ],
      }));
    }));

    final cards = (await service.generateFlashcards(_chapter)).valueOrNull!;
    expect(cards, hasLength(2));
    expect(cards.first.front, 'Q1');
    expect(cards.first.back, 'A1');
  });

  test('a refusal stop_reason becomes a failure', () async {
    final service = _service(MockClient((req) async => http.Response(
          jsonEncode({'content': [], 'stop_reason': 'refusal'}),
          200,
        )));
    final result = await service.explainPassage('some text');
    expect(result.isFailure, isTrue);
  });

  test('a non-200 response becomes a failure', () async {
    final service = _service(
        MockClient((req) async => http.Response('server error', 500)));
    final result = await service.translate('hola', targetLang: 'English');
    expect(result.isFailure, isTrue);
  });

  test('the disabled stub reports isEnabled=false', () {
    final service = AnthropicAiService(
      const AiConfig(baseUrl: 'https://proxy.test', enabled: false),
    );
    expect(service.isEnabled, isFalse);
  });
}
