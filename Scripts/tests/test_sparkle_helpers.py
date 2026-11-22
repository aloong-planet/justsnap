import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
# Gap: this pins the scripts' wiring, not the signed result. That a built app's Sparkle helpers carry no sandbox
# entitlement is checked by verify-macos-app.sh on every build; that an installed app then updates itself needs a
# second, newer release to update to, and nothing here runs that.
HELPERS = ("XPCServices/Downloader.xpc", "XPCServices/Installer.xpc", "Updater.app", "Autoupdate")


def codesign_commands(text):
    """Each `/usr/bin/codesign ...` invocation of a script, with its continuation lines joined."""
    joined = re.sub(r"\\\n\s*", " ", text)
    return [line.strip() for line in joined.splitlines() if line.strip().startswith("/usr/bin/codesign")]


class SparkleHelperSigningTests(unittest.TestCase):
    def test_build_script_does_not_sign_the_app_with_deep(self):
        text = (ROOT / "Scripts/build-macos-app.sh").read_text(encoding="utf-8")
        signing = [c for c in codesign_commands(text) if "--sign" in c]
        self.assertTrue(signing, "the build script signs nothing")
        for command in signing:
            self.assertNotIn("--deep", command)

    def test_release_signing_script_does_not_sign_with_deep(self):
        text = (ROOT / "Scripts/sign-developer-id-app.sh").read_text(encoding="utf-8")
        signing = [c for c in codesign_commands(text) if "--sign" in c]
        self.assertTrue(signing, "the signing script signs nothing")
        for command in signing:
            self.assertNotIn("--deep", command)

    def test_verify_script_checks_every_helper_for_the_sandbox_entitlement(self):
        text = (ROOT / "Scripts/verify-macos-app.sh").read_text(encoding="utf-8")
        for helper in HELPERS:
            self.assertIn(helper, text)
        self.assertIn("com.apple.security.app-sandbox", text.split("sparkle_current=", 1)[1])


if __name__ == "__main__":
    unittest.main()
