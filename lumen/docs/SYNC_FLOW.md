# Synchronization flow

Lumen never depends on connectivity. Every action is applied **locally first**
and returns immediately; the cloud converges later.

## Write path (local → cloud)

```
User action (add highlight, turn page, edit note, import book…)
      │
      ▼
Repository writes to local Isar  ──▶  UI updates reactively (instant)
      │
      ▼
Repository enqueues a SyncOperation in sync_queue
      │
      ▼
SyncEngine (drains queue when online)
      ├─ SyncQueue.dueOperations(now)   # respects per-op backoff gates
      ├─ push each op to Firestore/Storage
      ├─ success → complete(id)          # remove from queue
      └─ failure → fail(id, err, now)    # exponential backoff, retry ≤ 5
```

`SyncQueue` also **collapses** redundant pending updates to the same entity, so
rapid progress ticks upload only the latest state.

## Read path (cloud → local)

On sync, the engine pulls remote changes newer than the last sync watermark and
merges them through the `ConflictResolver` before writing locally. The UI, which
watches Isar, updates automatically.

## When sync runs

Automatic triggers (per spec):

- On login / app start
- Periodically **while reading** (debounced progress)
- When a book is closed
- When connectivity is **regained** (connectivity listener)
- Before logout (`flushBeforeLogout` drains the queue)

Offline, operations simply accumulate in the queue; nothing is lost.

## Conflict resolution rules

Implemented in `data/sync/conflict_resolver.dart` (pure Dart, unit‑tested):

| Data | Rule |
| --- | --- |
| **Reading position** | Newest wins (last‑write‑wins by `updatedAt`); ties never move progress backwards. |
| **Notes & highlights** | **Merge** both sides by id; newer edit wins per id. |
| **Bookmarks** | Merge by id. |
| **Deletions** | Tombstones (`isDeleted`), never hard delete. A deletion only wins over an **older** edit — an older tombstone cannot erase a newer edit. |
| **User data** | Never deleted automatically. |

## Cross‑device resume

`ReadingProgress` carries a `deviceId`. On opening a book, `ResolveResumePoint`
compares local vs. remote progress:

```
if remote is newer AND from a different device AND materially ahead:
    prompt "Continue from page X?"   # user chooses; nothing auto-overwrites
else:
    resume locally
```

## Backoff schedule

`SyncOperation.backoff` = `2^retryCount` seconds, capped at 5 minutes
(1s → 2s → 4s → 8s → 16s …). After 5 failed attempts an operation is parked and
surfaced for manual retry; it is never dropped.

## Guest → account migration

Guest data is stored under a local `guest-*` uid. On upgrade
(`UpgradeGuestAccount`), the account is created and the sync engine pushes all
local entities up under the new uid — books, notes, progress, bookmarks,
highlights, collections, settings and statistics. Where the backend supports
anonymous‑credential linking the uid is preserved and no copy is required.
Local data remains the source of truth throughout, so nothing is lost even if
the first push happens offline (it queues).
