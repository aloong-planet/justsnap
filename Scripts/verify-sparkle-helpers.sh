#!/bin/bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <Sparkle.framework/Versions/Current>" >&2
    exit 64
fi

sparkle_current="$1"

# Sparkle's installer must run outside the app's sandbox: a sandboxed installer is refused the administrator
# authorization it asks for, and the update fails after the new version is found and downloaded. Signing the app with
# --deep would stamp the app's entitlements on these helpers. A helper whose signature cannot be read fails too, so a
# renamed or unsigned helper is not waved through unchecked.
for helper in XPCServices/Downloader.xpc XPCServices/Installer.xpc Updater.app Autoupdate; do
    if ! entitlements="$(/usr/bin/codesign -d --entitlements - "$sparkle_current/$helper" 2>&1)"; then
        echo "Cannot read the signature of Sparkle helper $helper: $entitlements" >&2
        exit 1
    fi
    if /usr/bin/grep -Fq 'com.apple.security.app-sandbox' <<< "$entitlements"; then
        echo "Sparkle helper $helper carries the app's sandbox entitlement" >&2
        exit 1
    fi
done
