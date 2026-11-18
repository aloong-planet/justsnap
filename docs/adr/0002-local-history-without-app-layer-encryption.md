# ADR-0002: Keep local history without app-layer encryption

- Status: Accepted (2026-11-18)

## Context

VLMSnapper keeps original PNGs, Pasted Text, model source and translation text, operation states and a search index on this Mac. History search must stay fast and light in the background, and users open original PNGs straight from Finder. App-layer encryption would complicate direct viewing, full-text indexing, recovery and key migration, while plain files can be read by anyone who gains the user's account or disk access.

## Options

1. **Keep history as plain files, protected by macOS user permissions and optional FileVault**
2. Encrypt the images and the database with a data key kept in the Keychain — rejected: images could no longer be opened from Finder, full-text search would need a separate decrypting index, and key rotation, recovery, migration and performance would all cost more.
3. Keep no history — rejected: the product requires browsing, searching, rerunning and automatically cleaning up past captures and text results from the menu bar.

## Decision

We adopt **option 1**. History is kept as plain files in the locations ADR-0006 sets, and the folders and files the app creates are accessible only to the current macOS user. The app does not encrypt history at the application layer, offers no iCloud or other cloud history sync, and never uploads history on its own: an operation's input, an original image or a Pasted Text, goes to the current Provider only when that operation runs, at the moment the v1-core and clipboard-paste specs set.

The app sets no backup-exclusion attribute on user-visible PNGs. Copies made by Time Machine, corporate backup or third-party sync are under the user's control and outside the app's deletion and cleanup promise.

Provider API keys are not history data; ADR-0001 keeps them in the Keychain.

## Consequences

- Positive: original PNGs open directly from Finder, local full-text search needs no per-record decryption, and background CPU, memory and implementation cost stay low.
- Negative: anyone who gains the user's account, an unencrypted disk, a backup or the files themselves can read screenshots, Pasted Text and text history; the app must not describe its storage as end-to-end encrypted or zero-knowledge.
- Negative: copies in backups or third-party sync outlive the app's deletion and automatic cleanup.
- Neutral: whether FileVault is on is up to the user and the system, not guaranteed by VLMSnapper; automatic cleanup, manual deletion and permissions must still cover images, the database and related metadata.

## Sources

- The user's v1 storage and privacy decisions of 2026-08-25 and Pasted Text decisions of 2026-11-18 (alignment records in `docs/.workings/`, not committed).
- [ADR-0001](0001-store-provider-api-keys-in-apple-keychain.md)
- [ADR-0006: Keep original images in Pictures and history data in the app container](0006-layer-user-screenshots-and-internal-history-storage.md)
