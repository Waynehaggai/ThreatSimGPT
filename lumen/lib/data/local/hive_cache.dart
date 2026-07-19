import 'package:hive_flutter/hive_flutter.dart';

/// Lightweight, schema-less key/value cache for ephemeral UI state that does not
/// warrant an Isar collection (last library query, last-opened book id, feature
/// flags, "what's new" seen markers…).
///
/// Isar remains the source of truth for domain data; Hive is only a convenience
/// cache and may be cleared at any time without data loss.
class HiveCache {
  HiveCache(this._box);

  final Box<dynamic> _box;

  static const _boxName = 'lumen_cache';

  static Future<HiveCache> open() async {
    await Hive.initFlutter();
    final box = await Hive.openBox<dynamic>(_boxName);
    return HiveCache(box);
  }

  T? get<T>(String key, {T? defaultValue}) =>
      _box.get(key, defaultValue: defaultValue) as T?;

  Future<void> set<T>(String key, T value) => _box.put(key, value);

  Future<void> remove(String key) => _box.delete(key);

  Future<void> clear() => _box.clear();
}
