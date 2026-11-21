# ADR-0020: Serve formal releases and the Sparkle appcast from the download host

- Status: Accepted (2026-11-21)

## Context

Installed builds update from one appcast address baked into them (ADR-0004), so that address cannot change after the first public release. The release is built, signed and notarized on the maintainer's Mac and published as a GitHub Release. The maintainer controls the `aloongplanet.com` zone and a Cloudflare R2 bucket behind `dl.justsnap.aloongplanet.com`.

## Options

1. **Mirror the DMG and the appcast from the GitHub Release to R2 and serve both from the download host**
2. Point the app's appcast address at the GitHub Release asset URL — rejected: the address depends on GitHub's URL layout and on a release existing, and cannot be moved later without orphaning installed builds.
3. Upload from the maintainer's Mac straight to R2 — rejected: the R2 write credentials exist only as repository secrets, and a local upload would need a second copy of them.

## Decision

We adopt **option 1**. The download host serves the DMG at `releases/v<version>/`, the appcast at `appcast/appcast-arm64.xml` and the latest pointer at `latest.json`. A workflow copies them from the GitHub Release after a formal release is published: the DMG first, read back through the host and compared byte for byte, then the appcast, and the pointer last. The pointer never moves to a lower version.

## Consequences

- Positive: installed apps and the download page read from a host the maintainer controls, and the appcast address stays valid whatever happens to the GitHub repository.
- Positive: no file is made visible before the files it depends on are served and checked.
- Negative: a release exists in two places, and a failure between GitHub and R2 leaves installed apps on the previous version until the workflow is run again.
- Negative: rolling the pointer back to a lower version is a manual operation.
- Neutral: the appcast is generated on the maintainer's Mac, so its download URLs must already name the download host when it is built.

## Sources

- [release-mirror spec](../specs/release-mirror.md)
- The user's decision to host the appcast on R2 under `appcast/` of the download host, given on 2026-11-21: 「appcast 放 R2，按你的方案开工」.
