import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ENTRY = re.compile(r'"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;', re.S)
# The Chinese copy that points at a system surface (the system lists the app as JustSnap), and the storage path.
CHINESE_KEYS_KEEPING_ENGLISH_NAME = {
    "permissionRecovery.unavailable",
    "permissionRecovery.stepTwo",
    "settings.loginItem.approval",
    "privacy.storage.body",
}


def dictionary(language):
    path = ROOT / "JustSnap/Resources/Localization" / f"{language}.lproj/Localizable.strings"
    return dict(ENTRY.findall(path.read_text(encoding="utf-8")))


class ProductNameTests(unittest.TestCase):
    def test_product_name_is_justsnap_in_english_and_suishi_in_chinese(self):
        self.assertEqual(dictionary("en")["app.name"], "JustSnap")
        self.assertEqual(dictionary("zh-Hans")["app.name"], "随译")

    def test_chinese_dictionary_names_justsnap_only_where_it_points_at_a_system_surface(self):
        named = {key for key, value in dictionary("zh-Hans").items() if "JustSnap" in value}
        self.assertEqual(named, CHINESE_KEYS_KEEPING_ENGLISH_NAME)

    def test_chinese_dictionary_never_uses_the_former_name(self):
        self.assertEqual({key for key, value in dictionary("zh-Hans").items() if "VLMSnapper" in value}, set())

    def test_interface_sources_take_the_product_name_from_the_dictionary(self):
        offenders = [
            str(path.relative_to(ROOT))
            for path in sorted((ROOT / "JustSnap/UI").glob("*.swift"))
            if '"JustSnap"' in path.read_text(encoding="utf-8")
        ]
        self.assertEqual(offenders, [])


if __name__ == "__main__":
    unittest.main()
