#!/bin/bash

set -euo pipefail

if [[ $# -ne 6 && $# -ne 8 ]]; then
    echo "Usage: $0 <app> arm64 <version> <build-version> <feed-url> <sparkle-public-key> [<signing-metadata> <signing-identity>]" >&2
    exit 64
fi

app="$1"
architecture="$2"
version="$3"
build_version="$4"
feed_url="$5"
sparkle_public_key="$6"
signing_metadata="${7:-}"
signing_identity="${8:-}"
project_root="$(cd "$(dirname "$0")/.." && pwd)"
info="$app/Contents/Info.plist"
executable="$app/Contents/MacOS/JustSnapApp"

[[ -f "$info" ]]
[[ -x "$executable" ]]
[[ -d "$app/Contents/Frameworks/Sparkle.framework" ]]
[[ -d "$app/Contents/Resources/JustSnap_JustSnapUI.bundle" ]]
[[ -f "$app/Contents/Resources/AppIcon.icns" ]]

assert_plist_value() {
    local key="$1"
    local expected="$2"
    local actual
    actual="$(/usr/libexec/PlistBuddy -c "Print :$key" "$info")"
    if [[ "$actual" != "$expected" ]]; then
        echo "Unexpected $key: expected '$expected', got '$actual'" >&2
        exit 1
    fi
}

assert_plist_value CFBundleIdentifier com.loong.justsnap
assert_plist_value CFBundleIconFile AppIcon
assert_plist_value CFBundleShortVersionString "$version"
assert_plist_value CFBundleVersion "$build_version"
assert_plist_value LSMinimumSystemVersion 14.4
assert_plist_value LSUIElement true
assert_plist_value \
    NSScreenCaptureUsageDescription \
    "JustSnap needs access to screen content so you can capture a selected area for text extraction or translation."
assert_plist_value SUFeedURL "$feed_url"
assert_plist_value SUPublicEDKey "$sparkle_public_key"
assert_plist_value SUEnableAutomaticChecks true
assert_plist_value SUAllowsAutomaticUpdates false
assert_plist_value SUEnableInstallerLauncherService true
assert_plist_value SUEnableSystemProfiling false
assert_plist_value SURequireSignedFeed true
assert_plist_value SUVerifyUpdateBeforeExtraction true

assert_localized_plist_value() {
    local locale="$1"
    local expected="$2"
    local localized_info="$app/Contents/Resources/$locale.lproj/InfoPlist.strings"
    local actual
    if [[ ! -f "$localized_info" ]]; then
        echo "Missing localized Info.plist strings: $localized_info" >&2
        exit 1
    fi
    actual="$(
        /usr/bin/plutil \
            -extract NSScreenCaptureUsageDescription raw \
            -o - \
            "$localized_info"
    )"
    if [[ "$actual" != "$expected" ]]; then
        echo "Unexpected $locale NSScreenCaptureUsageDescription: expected '$expected', got '$actual'" >&2
        exit 1
    fi
}

assert_localized_plist_value \
    en \
    "JustSnap needs access to screen content so you can capture a selected area for text extraction or translation."
assert_localized_plist_value \
    zh-Hans \
    "JustSnap 需要访问屏幕内容，以便截取你选择的区域并进行文字提取或翻译。"

scheduled_interval="$(/usr/libexec/PlistBuddy -c "Print :SUScheduledCheckInterval" "$info")"
if [[ "$scheduled_interval" != "21600" && "$scheduled_interval" != "21600.000000" ]]; then
    echo "Unexpected SUScheduledCheckInterval: $scheduled_interval" >&2
    exit 1
fi

actual_architectures="$(/usr/bin/lipo -archs "$executable")"
case "$architecture" in
    arm64)
        [[ "$actual_architectures" == "arm64" ]]
        ;;
    *)
        echo "Unsupported architecture: $architecture" >&2
        exit 64
        ;;
esac

/usr/bin/otool -L "$executable" | /usr/bin/grep -Fq '@rpath/Sparkle.framework/'
/usr/bin/codesign --verify --deep --strict --verbose=2 "$app"

entitlements="$(mktemp "${TMPDIR:-/tmp}/justsnap-entitlements.XXXXXX")"
cleanup() {
    rm -f "$entitlements"
}
trap cleanup EXIT
/usr/bin/codesign -d --xml --entitlements :- "$app" > "$entitlements" 2>/dev/null

assert_entitlement_value() {
    local key="$1"
    local expected="$2"
    local actual
    actual="$(/usr/libexec/PlistBuddy -c "Print :$key" "$entitlements")"
    if [[ "$actual" != "$expected" ]]; then
        echo "Unexpected entitlement $key: expected '$expected', got '$actual'" >&2
        exit 1
    fi
}

assert_entitlement_value com.apple.security.app-sandbox true
assert_entitlement_value com.apple.security.assets.pictures.read-write true
# The capture toolbar's Save asks for a location in the system save panel (v1-core::REQ-009).
assert_entitlement_value com.apple.security.files.user-selected.read-write true
assert_entitlement_value com.apple.security.network.client true
assert_entitlement_value \
    com.apple.security.temporary-exception.mach-lookup.global-name:0 \
    com.loong.justsnap-spki
assert_entitlement_value \
    com.apple.security.temporary-exception.mach-lookup.global-name:1 \
    com.loong.justsnap-spks

# Sparkle's installer must run outside the app's sandbox: a sandboxed installer is refused the administrator
# authorization it asks for, and the update fails after the new version is found and downloaded. Signing the app with
# --deep would stamp the app's entitlements on these helpers.
sparkle_current="$app/Contents/Frameworks/Sparkle.framework/Versions/Current"
for helper in XPCServices/Downloader.xpc XPCServices/Installer.xpc Updater.app Autoupdate; do
    if /usr/bin/codesign -d --entitlements - "$sparkle_current/$helper" 2>&1 \
        | /usr/bin/grep -Fq 'com.apple.security.app-sandbox'; then
        echo "Sparkle helper $helper carries the app's sandbox entitlement" >&2
        exit 1
    fi
done

if [[ -n "$signing_metadata" ]]; then
    "$project_root/Scripts/verify-developer-id-app.sh" \
        "$app" \
        "$signing_metadata" \
        "$signing_identity"
fi
