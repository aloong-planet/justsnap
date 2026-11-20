#!/bin/bash

set -euo pipefail

version="${VERSION:-0.1.0}"
build_version="${BUILD_VERSION:-1}"
feed_base_url="${APPCAST_BASE_URL:-https://development.invalid/justsnap}"
sparkle_public_key="${SPARKLE_PUBLIC_ED_KEY:-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=}"
project_root="$(cd "$(dirname "$0")/.." && pwd)"
output_root="${OUTPUT_ROOT:-$project_root/release/$version-development}"

mkdir -p "$output_root"

architecture=arm64
feed_url="$feed_base_url/appcast-$architecture.xml"
app="$output_root/$architecture/JustSnap.app"
"$project_root/Scripts/build-macos-app.sh" \
    "$architecture" \
    "$version" \
    "$build_version" \
    "$feed_url" \
    "$sparkle_public_key" \
    "$app"
"$project_root/Scripts/verify-macos-app.sh" \
    "$app" \
    "$architecture" \
    "$version" \
    "$build_version" \
    "$feed_url" \
    "$sparkle_public_key"

staging="$(mktemp -d "${TMPDIR:-/tmp}/justsnap-dmg.XXXXXX")"
cleanup_staging() {
    rm -rf "$staging"
}
trap cleanup_staging EXIT
/usr/bin/ditto "$app" "$staging/JustSnap.app"
ln -s /Applications "$staging/Applications"
dmg="$output_root/JustSnap-$version-mac-$architecture.dmg"
rm -f "$dmg"
/usr/bin/hdiutil create \
    -quiet \
    -fs HFS+ \
    -format UDZO \
    -volname JustSnap \
    -srcfolder "$staging" \
    "$dmg"
cleanup_staging
trap - EXIT
/usr/bin/codesign --force --sign - "$dmg"
/usr/bin/hdiutil verify "$dmg"

echo "Development DMGs created in $output_root"
