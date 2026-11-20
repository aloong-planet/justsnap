# ADR-0006: Keep original images in Pictures and history data in the app container

- Status: Accepted (2026-11-18)

## Context

JustSnap runs in the App Sandbox and keeps two kinds of data: original images, which users browse in Finder and which are useful on their own, and internal history, used only for search and reruns. Apple grants a dedicated entitlement for the Pictures folder, and App Store review has treated long-lived user-visible files kept only in an app container as a storage problem. Pasted Text is an operation input that users do not browse as files.

## Options

1. Keep all images and internal data in the App Sandbox container — rejected: original PNGs are user-visible and useful on their own, and hiding them in the container risks review rejection and their loss on uninstall.
2. **Keep original PNGs in `~/Pictures/JustSnap/` and internal history data, Pasted Text included, in the container**
3. Ask the user to choose a folder at first launch and keep a security-scoped bookmark — rejected: it adds a setup step and bookmark expiry and recovery flows, while Pictures already has an entitlement that fits screenshots.
4. Put all data in a Pictures subfolder — rejected: the database, index and logs are not user images; they would clutter the user's folder and widen the risk of accidental edits.
5. Also write Pasted Text as a managed `.txt` file next to the PNGs — rejected by the user on 2026-11-18: it adds a second managed file type with its own hashing, missing-file and cleanup rules, and fills the Pictures folder with text files.

## Decision

We adopt **option 2**. The app declares `com.apple.security.assets.pictures.read-write` and saves original lossless PNGs in the `JustSnap/` subfolder of the system Pictures folder, found through the system directory API, never through a hard-coded home path or a container proxy path. The history database, Pasted Text, model results, the search index, operation states and logs stay in the container's `Library/Application Support/JustSnap/`. The image folder is fixed: there is no custom location and no migration. Folders are created on first need, and clearing history keeps the root folder.

A PNG is a Managed Capture File only when this installation created it and a history record stores its path and SHA-256. The app shows, uploads or deletes only Managed Capture Files, never scans outside `JustSnap/`, and does not import, claim or clean up PNGs left by an earlier installation or a cleared container. A path component that is a regular file, a symbolic link, or that resolves outside Pictures blocks saving and uploading.

An operation on an image first saves the PNG atomically with its SHA-256, then creates a "preparing request" record, and uploads only after both succeed. An operation on Pasted Text writes no file and uploads only after a "preparing request" record that holds the text is saved. A PNG whose record could not be created is deleted only when it is provably this attempt's file; otherwise it stays as an orphan that the app neither reports nor cleans up. When a complete result cannot be saved and the user discards it, the PNG and the prepared record stay, and the next launch classifies the operation as a result save failure; the model is never called again to repair storage.

Manual deletion and automatic cleanup remove a record together with its PNG when no other record uses that PNG; a Pasted Text record has no file, so only the record is removed.

## Consequences

- Positive: users find original images in Finder, and uninstalling the app does not delete them with the container; the location matches the screenshot purpose and the Pictures entitlement.
- Positive: the database, index, Pasted Text and logs stay in the container and need no extra user-folder permission.
- Negative: the app requests read-write access to the whole Pictures folder and must explain in review that it only creates, shows and cleans up the `JustSnap` subfolder.
- Negative: users can move, rename or delete PNGs in Finder, so history must handle a missing or replaced original without treating the record's image as usable.
- Negative: Pasted Text is not visible in Finder; it is reachable only through history, and deleting the record deletes it.
- Neutral: a fixed folder avoids the security-scoped bookmark lifecycle; a custom folder would need its own design for authorization, recovery and migration.

## Sources

- The user's v1 storage decisions of 2026-08-25 and Pasted Text storage decision of 2026-11-18 (alignment records in `docs/.workings/`, not committed).
- [Apple: App Sandbox](https://developer.apple.com/documentation/security/app-sandbox)
- [Apple: Pictures Folder Read/Write entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.assets.pictures.read-write)
- [Apple: Accessing files from the macOS App Sandbox](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)
- App Store Guideline 2.4.5(i) review case of the Transfer app (record not committed).
