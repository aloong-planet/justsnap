import AppKit
import Testing
import JustSnapCore
@testable import JustSnapUI

// clipboard-paste::REQ-001/AC-04: what General settings show while no paste shortcut is registered.
@Suite("Clipboard paste shortcut settings", .serialized)
@MainActor
struct ClipboardPasteShortcutSettingsTests {
    @Test("an unset paste shortcut says it conflicts and is not set, not that the previous one still works")
    func unsetNotice() {
        LocalizationTestCoordinator.withExclusiveAccess {
            JustSnapLocalization.configure(effectiveLanguage: .english)
            #expect(JustSnapStrings.shortcutFailure(.unset)
                == "The paste shortcut conflicts with another shortcut and is not set. Record a new one.")
            #expect(JustSnapStrings.shortcutFailure(.conflict)
                == "That shortcut is already in use. The previous shortcut remains active.")
            JustSnapLocalization.configure(effectiveLanguage: .simplifiedChinese)
            #expect(JustSnapStrings.shortcutFailure(.unset) == "粘贴快捷键与其他快捷键冲突，目前未设置。请录制新的快捷键。")
        }
    }

    @Test("the recorder shows Not set without a shortcut and the shortcut once one is set")
    func recorderLabel() {
        LocalizationTestCoordinator.withExclusiveAccess {
            JustSnapLocalization.configure(effectiveLanguage: .english)
            let recorder = ShortcutRecorderNSView()
            recorder.shortcut = nil
            #expect(recorder.accessibilityLabel() == "Not set")
            recorder.shortcut = .defaultPaste
            #expect(recorder.accessibilityLabel() == "⌥⇧V")
        }
    }
}
