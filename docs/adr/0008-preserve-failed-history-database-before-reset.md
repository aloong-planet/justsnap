# ADR-0008: Never silently rebuild a failed history database

- Status: Accepted (2026-11-18)

## Context

VLMSnapper requires a saved history record before it calls an online model, and the database holds image paths, SHA-256 values, model results, deletion eligibility and cleanup state. Calling the model while the database is broken produces results that cannot be reliably saved or managed. Deleting and rebuilding the database on its own silently loses history and leaves the PNGs in Pictures with no verifiable managing record.

## Options

1. Keep model operations available when the database is unavailable and skip history — rejected: it breaks the save-before-upload privacy and consistency boundary.
2. Delete a damaged database and create a new one automatically — rejected: it silently loses text results, the index and deletion eligibility.
3. **Block model operations, and reset only after the user explicitly confirms, keeping the original database**
4. Let an earlier app open a newer database read-only and prompt for an update — rejected on 2026-11-18: the app has no users on earlier versions yet, so the extra mode is not worth building.

## Decision

We adopt **option 3**. When the database is damaged or a schema migration fails, Text Extraction and translation are unavailable; Provider settings, general settings, diagnostic log export and Finder folder access stay available. The failure view lets the user retry opening, and the app never deletes, overwrites or silently rebuilds the database.

After the user explicitly confirms "reset history database", the app renames the original database to a timestamped recovery file and then creates an empty one. PNGs in Pictures stay as they are, but with no path and SHA-256 in the new database they are no longer Managed Capture Files and are neither imported nor cleaned up. Recovery files are never deleted automatically; only the user deletes them, explicitly, from the recovery view.

There are no daily or rolling database backups. The database uses transactions and SQLite WAL; a temporary backup is made only before a schema migration, deleted as soon as the migrated database reopens and passes an integrity check, and kept as a recovery file only when the migration fails.

An earlier app that finds a schema newer than it supports does not open the database and quits at startup; it never downgrades, writes or resets it.

## Consequences

- Positive: a database failure never lets images keep uploading without a reliable record, and never silently destroys data that may still be recoverable.
- Positive: the user can make the app usable again while keeping the original PNGs and the failed database for manual recovery.
- Negative: PNGs from before a reset do not come back into history; there is no database repair or image re-import.
- Negative: recovery files can take disk space for a long time and hold unencrypted history, so the recovery view must say so and let the user delete them.
- Negative: an earlier app cannot start at all on a newer database until the user installs a newer version.
- Neutral: no periodic copy exists to recover from occasional damage, but text the user deleted does not live on in rolling backups either.
- Neutral: a manual downgrade leaves the newer database untouched.

## Sources

- The user's v1 history storage decisions of 2026-08-25 and the decision of 2026-11-18 to keep an earlier app's startup behaviour (alignment records in `docs/.workings/`, not committed).
- [ADR-0002: Keep local history without app-layer encryption](0002-local-history-without-app-layer-encryption.md)
- [ADR-0006: Keep original images in Pictures and history data in the app container](0006-layer-user-screenshots-and-internal-history-storage.md)
