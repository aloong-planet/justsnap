# ADR-0007: Distribute v1 only as Developer ID builds

- Status: Accepted (2026-08-25)

## Context

VLMSnapper runs in the App Sandbox, which applies to directly distributed apps as well and does not require the Mac App Store. The release already ships Universal, Apple Silicon and Intel Developer ID DMGs, three Sparkle appcasts and an all-or-nothing release gate. A Mac App Store build would bring different signing, provisioning, update and testing boundaries.

## Options

1. **Ship only the three Developer ID DMGs in v1, with no Mac App Store build**
2. Also ship a Mac App Store build in v1 — rejected: it needs its own target, signing and provisioning, the App Store update mechanism, TestFlight checks and a fourth release pipeline, beyond the current scope.
3. Ship only a Mac App Store build in v1 — rejected: the product has settled on Sparkle, per-architecture installers and Developer ID direct distribution.

## Decision

We adopt **option 1**. v1 ships only the Universal, Apple Silicon and Intel DMGs, each Developer ID signed, notarized and stapled, and each updated through its own Sparkle appcast. v1 creates no Mac App Store target, submits nothing to the Mac App Store, uses no TestFlight, and keeps no Mac App Store product in the three-architecture release gate.

The App Sandbox and the entitlements it needs stay on in all three direct builds, as a security boundary and least-privilege design. Adding the Mac App Store later needs its own ADR, settling the bundle identifier, update mechanism, signing and provisioning, receipt validation, TestFlight and data compatibility across channels.

## Consequences

- Positive: the release matrix stays at three architectures, with no fourth channel and no separate review state.
- Positive: Sparkle updates, architecture keeping and the all-or-nothing release gate are the same for every v1 product.
- Negative: v1 cannot be found, bought or auto-updated through the Mac App Store; users install it only from direct distribution.
- Neutral: Mac App Store review cases still inform the design, since user file discoverability and minimal entitlements help the direct builds too, but passing that review is not a v1 delivery condition.

## Sources

- The user's v1 distribution decisions of 2026-08-25 (alignment records in `docs/.workings/`, not committed).
- [ADR-0004](0004-separate-sparkle-feeds-per-distribution-architecture.md)
- [ADR-0005](0005-stable-direct-distribution-application-identity.md)
- [ADR-0006: Keep original images in Pictures and history data in the app container](0006-layer-user-screenshots-and-internal-history-storage.md)
