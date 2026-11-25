# macOS signing and notarization

This page explains the inputs and guarantees of the installer builds. The commands themselves are declared under `macos-distribution` in `capabilities.toml`.

## Local builds

The `local` profile builds the arm64 DMG under `release/<version>-development/`. Its DMG is ad-hoc signed and not notarized, so it is only for development.

`VERSION`, `BUILD_VERSION`, `APPCAST_BASE_URL`, `SPARKLE_PUBLIC_ED_KEY` and `OUTPUT_ROOT` are optional and have development defaults.

## App icon

`Distribution/AppIcon.svg` is the source of the app icon, and `Distribution/AppIcon.icns` is rendered from it and committed. `build-macos-app.sh` copies the `.icns` into the app, and `verify-macos-app.sh` fails if the app's `Info.plist` does not name it or the file is missing. The website's icon files are the same artwork without the margin and shadow; `Scripts/site-assets.mjs` derives them from the SVG and sends them to the website repository ([website assets](site-assets.md)).

To change the icon, edit the SVG, render it to a 1024 px PNG with a transparent background, scale that to the ten sizes of a `.iconset` folder (16, 32, 128, 256 and 512 pt at 1x and 2x), and run `iconutil -c icns <folder> -o Distribution/AppIcon.icns`. Then run `node Scripts/site-assets.mjs` to send the website its icon files, derived from the SVG.

## Release builds

The `release` profile builds the same single arm64 package. It:

1. Signs the app with Developer ID and embeds the provisioning profile. Sparkle's helpers inside it (`Installer.xpc`, `Downloader.xpc`, `Updater.app`, `Autoupdate`) are signed one by one and keep Sparkle's own entitlements and never the app's; the app is never signed with `--deep`, because that would put the app's sandbox on the installer, which is then refused the authorization an update needs. `verify-macos-app.sh` fails, through `verify-sparkle-helpers.sh`, if a helper carries the sandbox entitlement or its signature cannot be read.
2. Notarizes and staples the app, then does the same for its DMG.
3. Checks the final DMG with `verify-macos-app.sh`, `spctl` and `stapler`.
4. Generates the Sparkle appcast and verifies its signatures.

The app also runs a Data Protection Keychain check after signing. Any failure stops the whole release, and files reach the output directory only after every step passes. That directory must not already exist.

### Command inputs

Set these before running the `release` command:

| Variable | Value |
|---|---|
| `VERSION` | Marketing version |
| `BUILD_VERSION` | Build version, which must increase with each release |
| `APPCAST_BASE_URL` | Public HTTPS directory for the appcast |
| `DOWNLOAD_BASE_URL` | Public HTTPS directory for the DMGs |
| `SPARKLE_PUBLIC_KEY` | Sparkle public key, which must match the private key below |
| `OUTPUT_ROOT` | Output directory |

The script also reads these credentials from the environment:

| Variable | Value |
|---|---|
| `MACOS_SIGNING_IDENTITY` | Developer ID Application identity |
| `MACOS_NOTARY_PROFILE` | `notarytool` keychain profile |
| `SPARKLE_PRIVATE_KEY_FILE` | File holding the Sparkle private key |
| `MACOS_PROVISIONING_PROFILE` | Developer ID provisioning profile for `com.loong.justsnap` |

The provisioning profile and private key stay outside the repository. The Sparkle tools must already exist under `.build/artifacts`, so resolve the Swift packages first.

## Publishing a release

The `release` command's output directory holds `JustSnap-<version>-mac-arm64.dmg` and `appcast-arm64.xml`. Run it with:

| Variable | Value |
|---|---|
| `APPCAST_BASE_URL` | `https://dl.justsnap.aloongplanet.com/appcast` |
| `DOWNLOAD_BASE_URL` | `https://dl.justsnap.aloongplanet.com/releases/v<version>` |

The appcast address is built into every installed app, so `APPCAST_BASE_URL` never changes. Then publish:

1. Create the GitHub Release as a draft with both files: `gh release create v<version> <dmg> <appcast> --draft --title "JustSnap <version>" --notes-file <notes>`.
2. Publish it: `gh release edit v<version> --draft=false`.

Publishing starts `mirror-release.yml`, which copies the DMG to R2, reads it back through the download host, and only then replaces the appcast and `latest.json` (`docs/specs/release-mirror.md`). If the run fails, start it again for the same tag from the Actions tab; it is safe to repeat. The R2 secrets it reads (`R2_ACCOUNT_ID`, `R2_BUCKET`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`) are written by the Terraform apps workflow in the infrastructure repository.

## CI

- `ci.yml` runs the repository checks on every pull request and push to `main`. The full test suite and the development package runs on pushes to `main` and on a pull request that changes more than documents, as `.github/ci/routing.json` decides. `CI gate` is the job that reports the result.
- The release gate is `bash Scripts/test-local-regression.sh --desktop`, run on the maintainer's Mac before a release (it includes the mirror's tests). It does not depend on GitHub.
- `formal-release-verification.yml` runs only when started manually. It checks the live Provider contracts, installs the credentials into a temporary keychain, runs the release build and uploads the result as the `JustSnap-<version>-verified` artifact. It needs the signing, notarization and Sparkle secrets below, which the repository does not have yet, so it cannot run today.

Neither the local gate nor the formal workflow publishes anything. Publishing is the manual step above.

The `release` command's last step, once the artifacts are in place, is the website's asset pull request (`node Scripts/site-assets.mjs`, [website assets](site-assets.md)); it does not run on a CI runner, and a failure of that step leaves the release as it is.

### Workflow secrets

- Signing: `MACOS_DEVELOPER_ID_P12_BASE64`, `MACOS_DEVELOPER_ID_P12_PASSWORD`, `MACOS_SIGNING_IDENTITY`, `MACOS_BUILD_KEYCHAIN_PASSWORD`, `MACOS_DEVELOPER_ID_PROVISIONING_PROFILE_BASE64`
- Notarization: `MACOS_NOTARY_APPLE_ID`, `MACOS_NOTARY_TEAM_ID`, `MACOS_NOTARY_PASSWORD`
- Sparkle: `SPARKLE_PRIVATE_KEY`, `SPARKLE_PUBLIC_KEY`
- Live Provider gate: `OPENAI_API_KEY`, `GEMINI_API_KEY`, `DEEPSEEK_API_KEY`, plus the `JUSTSNAP_OPENAI_MODEL`, `JUSTSNAP_GEMINI_MODEL` and `JUSTSNAP_DEEPSEEK_MODEL` repository variables
