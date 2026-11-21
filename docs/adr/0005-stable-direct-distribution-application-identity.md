# ADR-0005: Fix the direct-distribution application identity

- Status: Accepted (2026-11-21)

## Context

The Bundle Identifier takes part in the macOS Screen Recording permission, Keychain access, login item registration, Sparkle updates and code-signing identity. The product ships one direct-distribution build; if the identity changed after release, users could lose permissions, credential access and update continuity. The first public release has not shipped yet, so no user holds data under any identifier.

## Options

1. **One Bundle Identifier, `com.loong.justsnap`, carried by the direct-distribution build**
2. Keep `com.loong.vlmsnapper`, the name the product had before it was renamed — rejected: it would stay in every signed app, Keychain item and update feed, and could only be corrected later through a migration.
3. Use `com.aloongplanet.justsnap` — rejected: the existing Transfer app's direct-distribution build uses `com.loong.*`, and `com.aloongplanet.*` is for its Mac App Store variant.
4. A different Bundle Identifier per architecture build — rejected: were several architecture builds ever shipped, it would split one product into separate permission, Keychain, login item and update identities.

## Decision

We adopt **option 1**. The application's display name is `JustSnap` and the v1 direct-distribution Bundle Identifier is `com.loong.justsnap`. Any further architecture build would share it.

The Keychain service, login item, Screen Recording permission, Sparkle configuration and the provisioning profile all use this Bundle Identifier as their stable root. It is not changed in an ordinary upgrade; a change after the first public release needs its own ADR and an explicit migration plan.

## Consequences

- Positive: one application identity keeps the Keychain, TCC permissions, login item and automatic updates continuous across versions.
- Positive: the identifier matches the product name, so nobody has to explain or correct a mismatch later.
- Negative: changing the reverse-domain name after release needs a compatible migration, not just a build setting.
- Neutral: builds made under `com.loong.vlmsnapper` have their own container, Keychain items and permissions, which this identity does not read or migrate.
- Neutral: the application stores its data in the `JustSnap` directories and does not read or migrate data left in the directories of the pre-rename name.
- Neutral: ADR-0004 ships a single package, so macOS sees one application identity and no architecture variants exist to install side by side.

## Sources

- The user's decision of 2026-11-21 to change the Bundle Identifier before the first formal release: 「直接改成 justsnap 吧」 and 「确认，用 com.loong.justsnap」.
- [ADR-0004: Distribute one Apple silicon package with its own Sparkle appcast](0004-distribute-one-apple-silicon-package.md)
