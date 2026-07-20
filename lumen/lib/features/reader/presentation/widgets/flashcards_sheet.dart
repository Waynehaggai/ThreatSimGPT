import 'package:flutter/material.dart';

import '../../../../core/result/result.dart';
import '../../../../domain/services/ai_service.dart';

/// Bottom sheet that generates and reviews AI study flashcards for a chapter.
///
/// Shows a loading state while the request is in flight, then a swipeable deck
/// of tap‑to‑flip cards (question → answer), with a friendly error otherwise.
class FlashcardsSheet extends StatelessWidget {
  const FlashcardsSheet({required this.title, required this.future, super.key});

  final String title;
  final Future<Result<List<Flashcard>>> future;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required Future<Result<List<Flashcard>>> future,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => FlashcardsSheet(title: title, future: future),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Icon(Icons.style_rounded,
                    size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<Result<List<Flashcard>>>(
              future: future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return snapshot.data!.fold(
                  onSuccess: (cards) => cards.isEmpty
                      ? Center(
                          child: Text('No cards generated.',
                              style: theme.textTheme.bodyLarge))
                      : _Deck(cards: cards, scrollController: scrollController),
                  onFailure: (f) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(f.message,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A swipeable deck with a position indicator.
class _Deck extends StatefulWidget {
  const _Deck({required this.cards, required this.scrollController});
  final List<Flashcard> cards;
  final ScrollController scrollController;

  @override
  State<_Deck> createState() => _DeckState();
}

class _DeckState extends State<_Deck> {
  final _page = PageController();
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _page,
            itemCount: widget.cards.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: _FlipCard(card: widget.cards[i]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 20, top: 4),
          child: Text('${_index + 1} / ${widget.cards.length}',
              style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }
}

/// A single tap‑to‑flip card (front = question, back = answer).
class _FlipCard extends StatefulWidget {
  const _FlipCard({required this.card});
  final Flashcard card;

  @override
  State<_FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<_FlipCard> {
  bool _showBack = false;

  @override
  void didUpdateWidget(_FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card != widget.card) _showBack = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => setState(() => _showBack = !_showBack),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Card(
          key: ValueKey(_showBack),
          color: _showBack
              ? theme.colorScheme.secondaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_showBack ? 'ANSWER' : 'QUESTION',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                  const SizedBox(height: 12),
                  Text(
                    _showBack ? widget.card.back : widget.card.front,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 20),
                  Text('Tap to flip',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
