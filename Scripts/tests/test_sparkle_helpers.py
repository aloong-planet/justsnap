import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
# Gap: the two signing-script tests pin the scripts' wiring, not the signed result, and the helper check is run on
# stand-in binaries. That a built app's real helpers carry no sandbox entitlement is checked by verify-macos-app.sh
# on every build; that an installed app then updates itself needs a second, newer release to update to, and nothing
# here runs that.
HELPERS = ("XPCServices/Downloader.xpc", "XPCServices/Installer.xpc", "Updater.app", "Autoupdate")
SANDBOX = {"com.apple.security.app-sandbox": True}


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

    def test_app_verification_runs_the_helper_check(self):
        text = (ROOT / "Scripts/verify-macos-app.sh").read_text(encoding="utf-8")
        self.assertIn('"$project_root/Scripts/verify-sparkle-helpers.sh"', text)


@unittest.skipUnless(sys.platform == "darwin", "signs stand-in binaries with codesign")
class SparkleHelperCheckTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp(prefix="justsnap-helpers."))
        self.addCleanup(shutil.rmtree, self.root, ignore_errors=True)

    def sign(self, helper, entitlements):
        path = self.root / helper
        path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile("/usr/bin/true", path)
        path.chmod(0o755)
        command = ["/usr/bin/codesign", "--force", "--sign", "-"]
        if entitlements:
            plist = self.root / "entitlements.plist"
            plist.write_bytes(plistlib.dumps(entitlements))
            command += ["--entitlements", str(plist)]
        subprocess.run(command + [str(path)], check=True, capture_output=True)

    def tree(self, sandboxed=None):
        for helper in HELPERS:
            self.sign(helper, SANDBOX if helper == sandboxed else {})

    def check(self):
        return subprocess.run(
            [str(ROOT / "Scripts/verify-sparkle-helpers.sh"), str(self.root)],
            capture_output=True,
            text=True,
        )

    def test_accepts_helpers_without_the_sandbox_entitlement(self):
        self.tree()
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejects_each_helper_that_carries_the_sandbox_entitlement(self):
        for helper in HELPERS:
            with self.subTest(helper=helper):
                self.tree(sandboxed=helper)
                result = self.check()
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn(helper, result.stderr)

    def test_rejects_a_helper_it_cannot_read(self):
        self.tree()
        (self.root / "Autoupdate").unlink()
        result = self.check()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("Autoupdate", result.stderr)


if __name__ == "__main__":
    unittest.main()
