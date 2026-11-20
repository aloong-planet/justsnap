import AppKit
import SwiftUI
import Testing
import JustSnapCore
@testable import JustSnapUI

// v1-core::REQ-017. The row showing the new language once it is chosen is the application's publication,
// covered by the application tests. Gap: no test drives the real panel's mouse monitor with a press in the
// list. A mouse-down sent through the application into the popover window ends the test process; the rule
// that a press in a child window keeps the panel open is covered by `dismissalRouting`, and that the list is
// a child window of the panel below. Retest with the installed build.
@Suite("Menu bar translation language", .serialized)
@MainActor
struct MenuBarTranslationLanguageTests {
    @Test("below Capture and Paste and above Recent, a row names the target language in full and its list sets another")
    func languageRowNamesTheLanguageAndItsListSetsAnother() throws {
        try LocalizationTestCoordinator.withExclusiveAccess {
            JustSnapLocalization.configure(effectiveLanguage: .english)
            var changes: [String] = []
            let hosting = NSHostingView(rootView: MenuBarPanelView(
                recentItems: [],
                targetLanguageCode: "ja",
                targetLanguages: [
                    TargetLanguageOption(code: "en", name: "English"),
                    TargetLanguageOption(code: "ja", name: "Japanese"),
                ],
                onCapture: {},
                onOpenRecent: { _ in },
                onNavigate: { _ in },
                onCheckUpdates: {},
                onTargetLanguageChange: { changes.append($0) }
            ))
            hosting.frame = NSRect(x: 0, y: 0, width: MenuBarPanelMetrics.width, height: 420)
            let window = NSWindow(contentRect: hosting.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.contentView = hosting
            window.orderFront(nil)
            defer { window.orderOut(nil) }
            defer { closePopovers() }
            hosting.layoutSubtreeIfNeeded()

            let lines = try recognizedLines(in: hosting)
            func line(_ text: String) throws -> CGRect {
                try #require(lines.first { $0.text == text }, "\(text) among \(lines.map(\.text))").box
            }
            // Smaller is higher in the panel, whichever way the view's coordinates run.
            func top(_ box: CGRect) -> CGFloat { hosting.isFlipped ? box.minY : hosting.bounds.height - box.maxY }
            let label = try line("Translate to")
            // Text recognition reads the disclosure arrow after the name as a letter.
            let name = try #require(lines.first { $0.text.hasPrefix("Japanese") }).box
            let capture = try #require(lines.first { $0.text.hasSuffix("Capture") }).box
            let recent = try line("Recent")
            #expect(top(capture) < top(label))
            #expect(top(label) < top(recent))
            #expect(abs(label.midY - name.midY) < 4)
            #expect(name.minX > label.maxX)

            let before = popoverCount()
            try press(window, at: hosting.convert(NSPoint(x: name.midX, y: name.midY), to: nil))
            try waitUntil { popoverCount() > before }
            let popover = try #require(NSApp.windows.first { $0.className.contains("Popover") && $0.isVisible })
            // Attached to the panel, so the panel's outside-click rule counts a press in the list as inside it.
            #expect(window.childWindows?.contains(popover) == true)
            // The same list as the toolbar's: abbreviation first, then the name (v1-core::REQ-013/AC-04).
            let rows = try recognizedListText(
                options: [
                    TargetLanguageOption(code: "en", name: "English"),
                    TargetLanguageOption(code: "ja", name: "Japanese"),
                ],
                selectedCode: "ja"
            )
            #expect(rows.contains("EN"))
            #expect(rows.contains("English"))
            #expect(rows.contains("JA"))

            try press(popover, at: try languageRowPoint(in: popover, row: 0))

            try waitUntil { changes == ["en"] }
            try waitUntil { popoverCount() == before }
        }
    }
}
