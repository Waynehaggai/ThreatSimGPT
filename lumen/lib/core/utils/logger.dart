import 'dart:developer' as developer;

import 'package:logging/logging.dart';

/// Thin wrapper around `package:logging` so the rest of the app depends on a
/// single, swappable logging surface. In release builds this can be pointed at
/// Crashlytics / a file sink without touching call sites.
final class AppLogger {
  AppLogger(String name) : _logger = Logger(name);

  final Logger _logger;

  static bool _initialised = false;

  /// Wire up the root logger once, at app start.
  static void init({Level level = Level.INFO}) {
    if (_initialised) return;
    _initialised = true;
    Logger.root.level = level;
    Logger.root.onRecord.listen((record) {
      developer.log(
        record.message,
        time: record.time,
        level: record.level.value,
        name: record.loggerName,
        error: record.error,
        stackTrace: record.stackTrace,
      );
    });
  }

  void debug(String message) => _logger.fine(message);
  void info(String message) => _logger.info(message);
  void warning(String message, [Object? error]) =>
      _logger.warning(message, error);
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.severe(message, error, stackTrace);
}
