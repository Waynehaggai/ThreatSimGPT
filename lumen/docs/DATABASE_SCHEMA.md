# Database schema

Lumen is **offline‑first**: the **local database is the source of truth** and the
cloud is a replica. Two stores are used locally, mirrored to Firestore for sync.

- **Isar** — primary structured store (indexed, reactive queries): books,
  content, annotations, bookmarks, progress, collections, stats, sync queue.
- **Hive** — lightweight key/value caches (last query, ephemeral UI prefs).
- **flutter_secure_storage** — encryption keys, PIN hash, tokens.

The Isar collection classes live in `lib/data/local/models/` and are generated
from the domain entities via mappers; the shapes below are the logical schema.

## Local (Isar) collections

### `books`
| field | type | notes |
| --- | --- | --- |
| id | String (PK, indexed) | app UUID, also the sync key |
| title, author | String | indexed for search |
| format | enum | pdf/epub/txt/docx/… |
| filePath, coverPath | String? | app‑storage paths |
| fileSizeBytes, pageCount | int | |
| dateImported, lastOpened | DateTime | indexed (sort) |
| progressPercent | double | 0–1 |
| isFavorite, isArchived | bool | indexed |
| collectionIds | List\<String> | many‑to‑many |
| needsOcr, hasSmartContent | bool | pipeline flags |
| defaultMode | enum | original/smart |
| checksum | String? | dedupe + divergence detection |

### `book_content` (Smart Reading Mode cache)
`bookId` (indexed) → `chapters[]` → `blocks[]` (`type`, `text?`, `imagePath?`,
`charOffset`). Regenerable from the source file; excluded from cloud sync
(rebuilt per device to save storage/bandwidth).

### `annotations`
`id` (PK) · `bookId` (indexed) · `type` (highlight/underline/note/sticky) ·
`selectedText` · `noteText?` · `colorValue?` · anchor (`page?`,
`startOffset?`, `endOffset?`, `cfi?`, `chapterId?`) · `createdAt` · `updatedAt`
(conflict) · `isDeleted` (**tombstone — never hard‑deleted**).

### `bookmarks`
`id` (PK) · `bookId` (indexed) · `label?` · position (`page?`, `percent?`,
`charOffset?`, `cfi?`) · `chapterTitle?` · `previewText?` · `createdAt` ·
`isDeleted`.

### `progress`
One row per book. `bookId` (PK) · `page` · `percent` · `charOffset?` · `cfi?` ·
`chapterId?` · `mode` · `ttsSentenceIndex?` · `updatedAt` (LWW) · `deviceId`
(drives the cross‑device resume prompt).

### `collections`
`id` (PK) · `name` · `description?` · `colorValue?` · `iconCodePoint?` ·
`sortIndex` · `createdAt` · `updatedAt` · `isDeleted`.

### `settings`
Singleton row holding `ReadingSettings` (typography, theme, navigation, TTS,
sleep timer). Synced as one document.

### `statistics`
Singleton aggregate (`ReadingStats`) + a separate `reading_sessions` series for
per‑day/per‑hour rollups (streaks, productive hours, genre totals).

### `sync_queue`
`id` (PK) · `entityType` · `entityId` · `action` (create/update/delete) ·
`status` · `retryCount` · `lastError?` · `nextAttemptAt?` · `payload?` ·
`createdAt`. Drained by the sync engine.

## Cloud (Firestore) layout

Per‑user document tree; ids match local ids so sync is a keyed upsert.

```
users/{uid}
  books/{bookId}                # metadata only (file blobs → Storage)
  annotations/{annotationId}
  bookmarks/{bookmarkId}
  progress/{bookId}
  collections/{collectionId}
  settings/current
  statistics/current
```

Firebase **Storage**: `users/{uid}/books/{bookId}/original.<ext>` and
`cover.jpg`. Large blobs upload by reference from the sync queue; `book_content`
is **not** uploaded (rebuilt locally).

## Encryption at rest

The Isar DB is opened with an encryption key fetched from
`SecurityService.databaseEncryptionKey()`, stored only in the platform secure
enclave (Keychain/Keystore). Tokens and the PIN hash use
`flutter_secure_storage`. See [`ARCHITECTURE.md`](ARCHITECTURE.md) and the
security roadmap milestone.
