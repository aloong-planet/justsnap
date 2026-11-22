import plistlib
import re
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
# Gap: nothing here shows that the artwork looks right or that Finder and the Dock display it; that is checked by
# opening the built app. This pins the wiring: the declaration, the file, and the two scripts that carry it.
ICON_NAME = "AppIcon"
# The ten image types `iconutil` writes for a full iconset (16, 32, 128, 256 and 512 pt, each at 1x and 2x). The
# "info" chunk it also writes is metadata, not an image, so the test leaves it out.
ICNS_TYPES = {"ic04", "ic05", "ic07", "ic08", "ic09", "ic10", "ic11", "ic12", "ic13", "ic14"}


def icns_types(path):
    data = path.read_bytes()
    magic, total = struct.unpack(">4sI", data[:8])
    assert magic == b"icns", "not an icns file"
    assert total == len(data), "icns length header does not match the file"
    types, offset = [], 8
    while offset < total:
        kind, size = struct.unpack(">4sI", data[offset:offset + 8])
        assert size >= 8, "corrupt icns chunk"
        types.append(kind.decode("ascii"))
        offset += size
    return types


class AppIconTests(unittest.TestCase):
    def test_info_plist_names_the_icon_file(self):
        with (ROOT / "Distribution/Info.plist").open("rb") as handle:
            self.assertEqual(plistlib.load(handle).get("CFBundleIconFile"), ICON_NAME)

    def test_icon_file_is_a_complete_icns(self):
        path = ROOT / f"Distribution/{ICON_NAME}.icns"
        self.assertTrue(path.is_file(), f"{path} is missing")
        self.assertEqual(set(icns_types(path)) - {"info"}, ICNS_TYPES)

    def test_build_script_copies_the_icon_into_the_app(self):
        text = (ROOT / "Scripts/build-macos-app.sh").read_text(encoding="utf-8")
        self.assertRegex(
            text,
            rf'(?m)^cp "\$project_root/Distribution/{ICON_NAME}\.icns" "\$app/Contents/Resources/{ICON_NAME}\.icns"$',
        )

    def test_verify_script_checks_the_icon_declaration_and_file(self):
        text = (ROOT / "Scripts/verify-macos-app.sh").read_text(encoding="utf-8")
        self.assertRegex(text, rf"(?m)^assert_plist_value CFBundleIconFile {ICON_NAME}$")
        self.assertRegex(text, rf'(?m)^\[\[ -f "\$app/Contents/Resources/{ICON_NAME}\.icns" \]\]$')


if __name__ == "__main__":
    unittest.main()
