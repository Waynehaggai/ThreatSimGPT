import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/ask_book_providers.dart';
import '../providers/reader_providers.dart';

/// A chat-style panel that answers the reader's questions about the current
/// book. Questions are grounded in passages retrieved from the book (RAG), so
/// answers stay anchored to the text.
class AskBookScreen extends ConsumerStatefulWidget {
  const AskBookScreen({required this.bookId, super.key});

  final String bookId;

  @override
  ConsumerState<AskBookScreen> createState() => _AskBookScreenState();
}

class _AskBookScreenState extends ConsumerState<AskBookScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    await ref.read(askBookControllerProvider(widget.bookId).notifier).ask(text);
    // Scroll to the newest answer once it renders.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final turns = ref.watch(askBookControllerProvider(widget.bookId));
    final bookTitle =
        ref.watch(readerBookProvider(widget.bookId)).valueOrNull?.title ??
            'this book';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask about this book'),
        actions: [
          if (turns.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => ref
                  .read(askBookControllerProvider(widget.bookId).notifier)
                  .clear(),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: turns.isEmpty
                ? _EmptyState(bookTitle: bookTitle)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: turns.length,
                    itemBuilder: (context, i) => _TurnTile(turn: turns[i]),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask a question…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send_rounded),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TurnTile extends StatelessWidget {
  const _TurnTile({required this.turn});
  final QaTurn turn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Question bubble (aligned right).
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8, left: 40),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              turn.question,
              style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
            ),
          ),
        ),
        // Answer / loading / error.
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 20, right: 40),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: _answer(theme),
          ),
        ),
      ],
    );
  }

  Widget _answer(ThemeData theme) {
    if (turn.pending) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (turn.error != null) {
      return Text(
        turn.error!,
        style: TextStyle(color: theme.colorScheme.error),
      );
    }
    return SelectableText(
      (turn.answer ?? '').isEmpty ? 'No response.' : turn.answer!,
      style: theme.textTheme.bodyLarge,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.bookTitle});
  final String bookTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Ask anything about “$bookTitle”.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Answers are drawn from the book\'s own text.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
