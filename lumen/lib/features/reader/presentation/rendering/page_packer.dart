/// A packed page: the half-open range of item indices `[start, end)` it holds.
class PageRange {
  const PageRange(this.start, this.end);
  final int start;
  final int end;

  int get length => end - start;

  @override
  bool operator ==(Object other) =>
      other is PageRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'PageRange($start, $end)';
}

/// Greedy page packing for reflowable content.
///
/// Given the measured height of each atomic item (a laid-out line, or an image)
/// and the usable page height, packs items into as few pages as possible while
/// never overflowing a page. This is the pure, deterministic core of page-turn
/// mode; the Flutter layer measures item heights via `TextPainter` and feeds
/// them here, so all the tricky boundary logic is unit-testable.
///
/// An item taller than a full page (an oversized image) gets its own page
/// rather than being dropped.
class PagePacker {
  const PagePacker();

  List<PageRange> pack(List<double> itemHeights, double pageHeight) {
    if (itemHeights.isEmpty) return const [];
    if (pageHeight <= 0) return [PageRange(0, itemHeights.length)];

    final pages = <PageRange>[];
    var start = 0;
    var used = 0.0;

    for (var i = 0; i < itemHeights.length; i++) {
      final h = itemHeights[i];

      // An oversized single item: flush the current page, then give it its own.
      if (h > pageHeight) {
        if (i > start) {
          pages.add(PageRange(start, i));
        }
        pages.add(PageRange(i, i + 1));
        start = i + 1;
        used = 0.0;
        continue;
      }

      if (used + h > pageHeight && i > start) {
        // Doesn't fit — close the page and start a new one with this item.
        pages.add(PageRange(start, i));
        start = i;
        used = h;
      } else {
        used += h;
      }
    }

    if (start < itemHeights.length) {
      pages.add(PageRange(start, itemHeights.length));
    }
    return pages;
  }
}
