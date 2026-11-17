import Foundation
import Testing
@testable import VLMSnapperCore

@Suite("Global shortcut preference")
@MainActor
struct GlobalShortcutPreferenceStoreTests {
    @Test("a recorded shortcut persists across store instances")
    func roundTrip() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let shortcut = GlobalShortcut(
            keyCode: 8,
            modifiers: [.command, .option]
        )

        UserDefaultsGlobalShortcutStore(defaults: defaults).save(shortcut)

        #expect(
            UserDefaultsGlobalShortcutStore(defaults: defaults).load()
                == shortcut
        )
    }

    @Test("incomplete persisted values fall back to the default")
    func incompleteValuesFallBack() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(8, forKey: "captureShortcut.keyCode")

        #expect(
            UserDefaultsGlobalShortcutStore(defaults: defaults).load()
                == .defaultCapture
        )
    }

    @Test("the paste shortcut has its own preference and falls back to ⌥⇧V")
    func pasteShortcutIsItsOwnPreference() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let paste = UserDefaultsGlobalShortcutStore(
            defaults: defaults,
            keyPrefix: "pasteShortcut",
            defaultShortcut: .defaultPaste
        )
        #expect(paste.load() == GlobalShortcut(keyCode: 9, modifiers: [.option, .shift]))

        UserDefaultsGlobalShortcutStore(defaults: defaults).save(GlobalShortcut(keyCode: 8, modifiers: [.command]))
        #expect(paste.load() == .defaultPaste)

        defaults.set(8, forKey: "pasteShortcut.keyCode")
        #expect(paste.load() == .defaultPaste)
    }
}
