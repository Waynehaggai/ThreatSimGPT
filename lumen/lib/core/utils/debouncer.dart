import 'dart:async';

/// Coalesces rapid calls into a single trailing invocation.
///
/// Used to persist reading progress: scrolling fires position updates on every
/// frame, but we only write to the DB / sync queue once the reader settles
/// (see [AppConstants.progressPersistDebounce]).
class Debouncer {
  Debouncer(this.duration);

  final Duration duration;
  Timer? _timer;

  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  /// Runs any pending action immediately (e.g. when the book is closed).
  void flush(void Function() action) {
    if (_timer?.isActive ?? false) {
      _timer!.cancel();
      action();
    }
  }

  void dispose() => _timer?.cancel();
}
