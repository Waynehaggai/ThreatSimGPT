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
| `translate` | Selection toolbar → 🌐 → language picker | Prose |
| `answerAboutBook` | Reader overflow menu → "Ask about this book" (RAG chat panel) | Prose |
| `answerQuestion` | (raw, non‑RAG; used as the empty‑passage fallback) | Prose |
| `generateFlashcards` | Reader overflow menu → "Flashcards" (swipeable flip‑card deck) | Structured (Q/A cards) |

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

## Retrieval (RAG) — grounded Q&A

The "Ask about this book" panel (`answerAboutBook`) uses classic RAG. On each
question:

1. `retrievePassages` (`features/reader/presentation/rendering/passage_retriever.dart`)
   scores every text block of the already‑reflowed `BookContent` against the
   question — a dependency‑free bag‑of‑words TF with an IDF‑style rarity boost
   and √length normalisation — and returns the top‑N passages. It's a pure
   function, so it's fast, offline, and unit‑tested; a future upgrade can swap
   in vector search behind the same signature without touching callers.
2. `AnthropicAiService.answerAboutBook` numbers those passages into the prompt
   and instructs the model to answer **only** from them, or say it couldn't find
   the answer — reducing hallucination. With no passages it falls back to
   `answerQuestion` (answer from the question alone).

The chat UI lives in `features/reader/presentation/screens/ask_book_screen.dart`,
driven by `AskBookController` (`providers/ask_book_providers.dart`), reached from
the reader's overflow menu at route `/ask/:bookId`.

## Tests

`test/data/anthropic_ai_service_test.dart` exercises request construction
(endpoint, model, headers, no client‑side key), prose parsing, structured‑output
parsing (dictionary + flashcards), grounded Q&A prompt construction, refusal
handling, and HTTP‑error handling — all with a mock `http.Client`, no network.
`test/features/passage_retriever_test.dart` covers the RAG retriever (ranking,
irrelevant‑query rejection, min‑length filtering, and the result limit).
