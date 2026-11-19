# ADR-0005: Fix the direct-distribution application identity

- Status: Accepted (2026-08-25)

## Context

The Bundle Identifier takes part in the macOS Screen Recording permission, Keychain access, login item registration, Sparkle updates and code-signing identity. The product ships three direct-distribution builds (Universal, arm64, x64); if they used different identities, or the identity changed after release, users could lose permissions, credential access and update continuity.

## Options

1. **One Bundle Identifier, `com.loong.vlmsnapper`, shared by all three architectures**
2. Use `com.aloongplanet.vlmsnapper` — rejected: the existing Transfer app's direct-distribution build uses `com.loong.*`, and `com.aloongplanet.*` is for its Mac App Store variant.
3. A different Bundle Identifier per architecture — rejected: it would split one product into three separate permission, Keychain, login item and update identities.

## Decision

We adopt **option 1**. The application's display name is `JustSnap` and the v1 direct-distribution Bundle Identifier is `com.loong.vlmsnapper`, the name the product had before it was renamed. The Universal, arm64 and x64 builds share it; only the build architecture and the Sparkle appcast address may differ.

The Keychain service, login item, Screen Recording permission and Sparkle configuration all use this Bundle Identifier as their stable root. It is not changed in an ordinary upgrade; a change needs its own ADR and an explicit migration plan.

## Consequences

- Positive: the three architectures share one application identity, so the Keychain, TCC permissions, login item and automatic updates stay continuous across versions.
- Negative: changing the reverse-domain name after release needs a compatible migration, not just a build setting.
- Negative: the identifier no longer matches the product name, so it must not be "corrected" to follow the display name.
- Neutral: the architectures keep separate update artifacts through the separate appcasts of ADR-0004, but macOS sees one application identity, so users should not install several architecture variants side by side.

## Sources

- The user's v1 identity decisions of 2026-08-25 (alignment record in `docs/.workings/`, not committed).
- [ADR-0004: 为三个发行架构使用独立 Sparkle appcast](0004-separate-sparkle-feeds-per-distribution-architecture.md)
