import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Reports device connectivity and notifies the sync engine when the device
/// comes back online (one of the automatic sync triggers).
class ConnectivityService {
  ConnectivityService([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// `true` when at least one non‑`none` transport is available.
  Future<bool> get isOnline async {
    final results = await _connectivity.checkConnectivity();
    return _hasConnection(results);
  }

  /// Emits `true`/`false` as connectivity changes. The sync engine listens to
  /// the rising edge (false → true) to flush the queue.
  Stream<bool> get onlineChanges =>
      _connectivity.onConnectivityChanged.map(_hasConnection).distinct();

  bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}
