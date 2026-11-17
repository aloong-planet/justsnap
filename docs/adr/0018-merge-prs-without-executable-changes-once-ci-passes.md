# ADR-0018: Merge PRs without executable changes once CI passes

- Status: Accepted (2026-11-17)

## Context

A PR waits for the user's explicit approval before it merges, including a PR that changes only documents, whose mistakes show when the documents are read and go away when it is reverted. The user wants such PRs to land without that round trip, while files that change how agents work in this repository still get read by the user first.

## Options

1. **Merge without approval a PR that changes no executable content, once CI on its head passes, unless it touches `AGENTS.md` or `CLAUDE.md`**
2. Keep waiting for approval on every PR — rejected by the user on 2026-11-17 (reason not recorded).
3. Merge documentation-only PRs without approval even when they touch `AGENTS.md` or `CLAUDE.md` — rejected by the user on 2026-11-17: those files direct every agent working here, so the user reads them before they land.
4. Also hold PRs that touch `docs/specs/`, `docs/adr/` or `docs/prototypes/` — offered and not chosen by the user on 2026-11-17 (reason not recorded).

## Decision

We adopt **option 1**: the project enables `docs-auto-merge` in `capabilities.toml`, whose conditions are those of the implement skill's delivery rules, and `AGENTS.md` keeps every PR that touches `AGENTS.md` or `CLAUDE.md` waiting for the user's approval.

## Consequences

- Positive: documentation-only PRs land as soon as CI passes, without waiting for the user.
- Negative: a wrong statement in a spec, ADR or prototype reaches `main` without the user reading it, and is caught only by a later documentation regression or a reader.
- Neutral: a Swift file whose only change is a comment counts as executable content, so such a PR still waits for approval.

## Sources

- The user's decisions of 2026-11-17, given when `docs-auto-merge` was added to `capabilities.toml`.
