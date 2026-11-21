import plistlib
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
# The expected identifier is a literal on purpose: it is the application identity (ADR-0005), so a change to it
# must fail here until the files this test reads have been changed too. It does not read the docs that name the
# identifier (ADR-0005, docs/ops/macos-signing.md).
#
# Gap: nothing here proves that a Developer ID provisioning profile exists for this App ID, that Sparkle's XPC
# services connect under these names, or that the Data Protection Keychain works with the profile
# (v1-core failure modes 20 and 22). Those are checked when a release is built, by Scripts/verify-macos-app.sh and
# the --verify-data-protection-keychain smoke in Scripts/release-macos.sh, which need the real profile.
BUNDLE_ID = "com.loong.justsnap"
IDENTIFIER_FAMILY = re.compile(r"com\.loong\.[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*")

SCRIPTS_THAT_NAME_THE_IDENTITY = [
    "Scripts/sign-developer-id-app.sh",
    "Scripts/test-live-provider.sh",
    "Scripts/verify-macos-app.sh",
]


def load_plist(relative):
    with (ROOT / relative).open("rb") as handle:
        return plistlib.load(handle)


class ApplicationIdentityTests(unittest.TestCase):
    def test_app_bundle_identifier_is_justsnap(self):
        self.assertEqual(load_plist("Distribution/Info.plist")["CFBundleIdentifier"], BUNDLE_ID)

    def test_live_provider_gate_uses_the_app_identifier(self):
        self.assertEqual(load_plist("Distribution/LiveProviderGate-Info.plist")["CFBundleIdentifier"], BUNDLE_ID)

    def test_sparkle_xpc_exceptions_are_named_after_the_app_identifier(self):
        entitlements = load_plist("Distribution/JustSnap.entitlements")
        self.assertEqual(
            entitlements["com.apple.security.temporary-exception.mach-lookup.global-name"],
            [f"{BUNDLE_ID}-spki", f"{BUNDLE_ID}-spks"],
        )

    def test_shared_preference_exception_is_the_app_identifier_only(self):
        entitlements = load_plist("Distribution/JustSnap.entitlements")
        self.assertEqual(
            entitlements["com.apple.security.temporary-exception.shared-preference.read-write"],
            [BUNDLE_ID],
        )

    def test_keychain_service_is_scoped_by_the_app_identifier(self):
        source = (ROOT / "Sources/JustSnapCore/AppleKeychainProviderCredentialStore.swift").read_text(encoding="utf-8")
        match = re.search(r'defaultService\s*=\s*"([^"]+)"', source)
        self.assertIsNotNone(match, "defaultService literal not found")
        self.assertEqual(match.group(1), f"{BUNDLE_ID}.provider-api-key")

    def test_scripts_pass_the_app_identifier_and_name_no_other_identity(self):
        for relative in SCRIPTS_THAT_NAME_THE_IDENTITY:
            with self.subTest(script=relative):
                text = (ROOT / relative).read_text(encoding="utf-8")
                found = IDENTIFIER_FAMILY.findall(text)
                self.assertTrue(found, "script names no identifier")
                for identifier in found:
                    self.assertTrue(
                        identifier == BUNDLE_ID or identifier.startswith(f"{BUNDLE_ID}-"),
                        f"{identifier} is not derived from {BUNDLE_ID}",
                    )

    def test_scripts_use_the_identifier_where_the_profile_and_the_built_app_are_checked(self):
        q = re.escape(BUNDLE_ID)
        expectations = {
            # JustSnapSigningTool prepare <profile> <bundle identifier> ...: the identifier the profile must match.
            "Scripts/sign-developer-id-app.sh": [rf'prepare\s+\\\s*\n\s*"\$profile"\s+\\\s*\n\s*{q}\s+\\'],
            "Scripts/test-live-provider.sh": [rf'prepare\s+"\$profile"\s+{q}\s'],
            # The built app's own identifier and the two Sparkle mach-lookup names.
            "Scripts/verify-macos-app.sh": [
                rf"^assert_plist_value CFBundleIdentifier {q}$",
                rf"global-name:0\s+\\\s*\n\s*{q}-spki$",
                rf"global-name:1\s+\\\s*\n\s*{q}-spks$",
            ],
        }
        for relative, patterns in expectations.items():
            text = (ROOT / relative).read_text(encoding="utf-8")
            for pattern in patterns:
                with self.subTest(script=relative, pattern=pattern):
                    self.assertRegex(text, re.compile(pattern, re.MULTILINE))


if __name__ == "__main__":
    unittest.main()
