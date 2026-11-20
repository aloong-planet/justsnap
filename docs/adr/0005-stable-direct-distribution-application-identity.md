# ADR-0005: Fix the direct-distribution application identity

- Status: Accepted (2026-08-25)

## Context

The Bundle Identifier takes part in the macOS Screen Recording permission, Keychain access, login item registration, Sparkle updates and code-signing identity. The product ships one direct-distribution build; if the identity changed after release, users could lose permissions, credential access and update continuity.

## Options

1. **One Bundle Identifier, `com.loong.vlmsnapper`, carried by the direct-distribution build**
2. Use `com.aloongplanet.vlmsnapper` — rejected: the existing Transfer app's direct-distribution build uses `com.loong.*`, and `com.aloongplanet.*` is for its Mac App Store variant.
3. A different Bundle Identifier per architecture build — rejected: were several architecture builds ever shipped, it would split one product into separate permission, Keychain, login item and update identities.

## Decision

We adopt **option 1**. The application's display name is `JustSnap` and the v1 direct-distribution Bundle Identifier is `com.loong.vlmsnapper`, the name the product had before it was renamed. Any further architecture build would share it.

The Keychain service, login item, Screen Recording permission and Sparkle configuration all use this Bundle Identifier as their stable root. It is not changed in an ordinary upgrade; a change needs its own ADR and an explicit migration plan.

## Consequences

- Positive: one application identity keeps the Keychain, TCC permissions, login item and automatic updates continuous across versions.
- Negative: changing the reverse-domain name after release needs a compatible migration, not just a build setting.
- Negative: the identifier no longer matches the product name, so it must not be "corrected" to follow the display name.
- Neutral: the application stores its data in the `JustSnap` directories and does not read or migrate data left in the directories of the pre-rename name.
- Neutral: ADR-0004 ships a single package, so macOS sees one application identity and no architecture variants exist to install side by side.

## Sources

- The user's v1 identity decisions of 2026-08-25 (alignment record in `docs/.workings/`, not committed).
- [ADR-0004: Distribute one Apple silicon package with its own Sparkle appcast](0004-distribute-one-apple-silicon-package.md)
