# AI Module

Lumen's AI features are built on Anthropic's Claude. The module plugs into the
core through the `AiService` interface (`domain/services/ai_service.dart`) — the
reader and library never depend on Claude directly, so the backend can change
without touching the app.

## Capabilities

| Method | Surface | Output |
| --- | --- | --- |
| `summarizeChapter` | Reader overflow menu → "Summarize chapter" | Prose |
| `explainPassage` | Selection toolbar → ✦ (multi‑word selection) | Prose |
| `defineWord` | Selection toolbar → ✦ (single word) | Structured (word/phonetic/meanings) |
| `translate` | (wired next) | Prose |
| `answerQuestion` | (wired next) | Prose |
| `generateFlashcards` | (wired next) | Structured (Q/A cards) |

Roadmap capabilities (dictionary, translation, Q&A, flashcards, quizzes, mind
maps, vocabulary, knowledge graphs, recommendations) all map onto this one
interface — adding a feature is a new method + a UI entry point, not an
architecture change.

## Model

`claude-opus-4-8` — the latest, most capable Claude model. Prose tasks
(summaries, explanations, Q&A) use **adaptive thinking** at `medium` effort;
structured tasks (dictionary, flashcards) use the Messages API's
**structured‑output** format for reliable JSON. Both are configurable per
request in `AnthropicAiService`.

## Architecture

- `domain/services/ai_service.dart` — the interface + `DisabledAiService`
  (the default; every method returns a clear failure so the app runs with AI
  off).
- `data/services/anthropic_ai_service.dart` — the Claude implementation. Dart
  has no official Anthropic SDK, so it calls the Messages API (`POST
  /v1/messages`) over raw HTTP via an injected `http.Client` (which makes
  request construction and response parsing unit‑testable with a mock client).
- DI: `aiConfigProvider` (`null` = off) gates `aiServiceProvider`, which returns
  `AnthropicAiService` when an `AiConfig` is present and `DisabledAiService`
  otherwise. UI checks `aiService.isEnabled` before showing AI actions.

## ⚠️ Security — never ship an API key in the app

A mobile binary is untrusted; an embedded `x-api-key` can be extracted. **In
production, point `AiConfig.baseUrl` at your own backend proxy**, which holds the
Anthropic key server‑side and forwards to `https://api.anthropic.com/v1/messages`.
The proxy is also where you enforce authentication, per‑user rate limits, and
spend caps. The `AiConfig.apiKey` field exists only for local development
against the API directly and must stay `null` in released builds.

```
App (AnthropicAiService)  ──HTTPS──▶  Your proxy  ──x-api-key──▶  Anthropic API
        no key                    (key + authz + limits)
```

## Enabling it

Provide an `AiConfig` via a provider override (e.g. in `main.dart`, driven by a
`--dart-define`d proxy URL):

```dart
ProviderScope(
  overrides: [
    ...await buildProductionOverrides(),
    aiConfigProvider.overrideWithValue(
      const AiConfig(baseUrl: 'https://api.yourapp.com/ai'),
    ),
  ],
  child: const LumenApp(),
);
```

With no override, AI stays off and the reader hides its AI actions.

## Retrieval (answerQuestion) — the next step

`answerQuestion` currently answers from the question alone. The production path
retrieves relevant passages from the book (the reflowed `BookContent` is already
chunk‑and‑offset friendly) and injects them into the system prompt — classic
RAG. This is the one AI method that needs the retrieval layer before it's fully
useful; the others operate on content the caller already holds.

## Tests

`test/data/anthropic_ai_service_test.dart` exercises request construction
(endpoint, model, headers, no client‑side key), prose parsing, structured‑output
parsing (dictionary + flashcards), refusal handling, and HTTP‑error handling —
all with a mock `http.Client`, no network.
