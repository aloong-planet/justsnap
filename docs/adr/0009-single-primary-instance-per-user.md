# ADR-0009: Allow one primary application instance per user

- Status: Accepted (2026-08-25)

## Context

JustSnap is a menu-bar app without a Dock icon. It owns the global capture hotkey, the single active model task, the SQLite history database, the managed screenshots in Pictures, the automatic cleanup schedule and the Sparkle update state, yet users can open it twice, run `open -n`, or start builds that share one Bundle Identifier. Several full instances would break the single-task rule and cause hotkey conflicts, concurrent database writes and duplicate cleanup.

## Options

1. Allow several full instances, coordinated by SQLite and file locks — rejected: the global hotkey, the single active task, the menu-bar state and Sparkle would still conflict.
2. **One primary instance per macOS user; a later instance only wakes it and exits**
3. Exit silently when an instance already exists — rejected: a user who opens the app again needs visible feedback.

## Decision

We adopt **option 2**. A second instance must not open or change the history database, register the global hotkey, run automatic cleanup or trigger an update check; it only sends an activation notice to the primary instance and exits at once. On that notice the primary instance brings a visible window or capture interface that can become the key window to the front, and opens the menu-bar panel when there is none.

Exclusion is per macOS user. Stale state left by an abnormal exit must be safely reclaimed by a later launch and must never block the app permanently. Builds that share the Bundle Identifier and are installed side by side still leave the first one started as the primary instance.

## Consequences

- Positive: the database, the managed screenshots, the hotkey, cleanup and update scheduling always have one writer and coordinator.
- Positive: a repeated launch gives the user clear feedback instead of creating a second, identical menu-bar icon.
- Negative: users cannot run independent JustSnap sessions with different Providers at the same time.
- Neutral: the Sparkle installer and its signed helper processes are not application instances, and the exclusion must not block them.

## Sources

- [ADR-0004: Distribute one Apple silicon package with its own Sparkle appcast](0004-distribute-one-apple-silicon-package.md)
- [ADR-0005: Fix the direct-distribution application identity](0005-stable-direct-distribution-application-identity.md)
- [ADR-0008: Never silently rebuild a failed history database](0008-preserve-failed-history-database-before-reset.md)
- The v1 requirements alignment record (`docs/.workings/v1-core/requirements-alignment.md`, not committed).
