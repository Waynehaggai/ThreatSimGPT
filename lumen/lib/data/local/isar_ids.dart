import 'package:isar/isar.dart';

/// Derives a stable Isar [Id] (64‑bit int) from a domain string id (UUID).
///
/// Domain entities are keyed by string UUIDs, but Isar's primary key is an int.
/// Hashing the UUID gives a **deterministic** id, so `put()` performs an
/// in‑place upsert for the same entity across app restarts and devices — no
/// separate "does it exist yet?" query needed.
///
/// FNV‑1a 64‑bit (the algorithm recommended in the Isar docs). Collision
/// probability across a 20k+‑book library is negligible; the original `uid`
/// string is also stored and indexed for exact lookups and as a tiebreaker.
Id fastHash(String string) {
  var hash = 0xcbf29ce484222325;
  for (var i = 0; i < string.length; i++) {
    final codeUnit = string.codeUnitAt(i);
    hash ^= codeUnit >> 8;
    hash *= 0x100000001b3;
    hash ^= codeUnit & 0xFF;
    hash *= 0x100000001b3;
  }
  return hash;
}
