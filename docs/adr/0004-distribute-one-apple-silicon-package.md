# ADR-0004: Distribute one Apple silicon package with its own Sparkle appcast

- Status: Accepted (2026-11-20)

## Context

JustSnap is distributed directly as a Developer ID DMG and updated through Sparkle. An installed build keeps updating from the appcast address baked into it, so the set of packages and the update feeds must agree on which builds exist. The product targets Apple silicon Macs running macOS 14.4 or later.

## Options

1. **One Apple silicon (arm64) package with one appcast, released all-or-nothing**
2. Universal, Apple silicon and Intel packages, each with its own appcast — rejected (not recorded; positioning exclusion): the user chose to ship Apple silicon only.
3. A single Universal package with one appcast — rejected (not recorded; positioning exclusion): the user chose to ship Apple silicon only.

## Decision

We adopt **option 1**. Every release ships one DMG, `JustSnap-<version>-mac-arm64.dmg`, whose app embeds the HTTPS address of one appcast, `appcast-arm64.xml`; the appcast is signed with the Sparkle EdDSA key and carries the same version as the DMG.

The release publishes only when the build, Developer ID signing, Apple notarization, stapling, Sparkle EdDSA signing and appcast generation all succeed; any failure leaves the public appcast unchanged.

## Consequences

- Positive: there is one download, one feed and one set of release artifacts, so versions cannot disagree between packages.
- Positive: the release pipeline and a rollback have fewer steps.
- Negative: Intel Macs cannot run the app, and no package exists for them.
- Neutral: only the app's own executable is arm64-only; the Sparkle framework inside it keeps the architectures its vendor ships.

## Sources

- The user's decisions of 2026-11-20: Apple silicon only, and a single-package release pipeline (alignment record in `docs/.workings/justsnap-site/`, not committed).
- [Sparkle: Publishing an update](https://sparkle-project.org/documentation/publishing/)
