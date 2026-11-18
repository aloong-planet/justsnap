import AppKit
import SwiftUI
import Testing
import VLMSnapperCore
@testable import VLMSnapperUI

// v1-core::REQ-017. The panel staying open while its language list is used, and the row showing the new
// language afterwards, need the real panel and the application: the application tests and the installed build
// cover them.
@Suite("Menu bar translation language", .serialized)
@MainActor
struct MenuBarTranslationLanguageTests {
    @Test("below Capture and Paste and above Recent, a row names the target language in full and its list sets another")
    func languageRowNamesTheLanguageAndItsListSetsAnother() throws {
        try LocalizationTestCoordinator.withExclusiveAccess {
            VLMSnapperLocalization.configure(effectiveLanguage: .english)
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
            let content = try #require(popover.contentView)
            var table: NSTableView?
            try waitUntil {
                content.layoutSubtreeIfNeeded()
                table = allSubviews(content).compactMap { $0 as? NSTableView }.first
                return (table?.numberOfRows ?? 0) == 2
            }
            // The same list as the toolbar's: abbreviation first, then the name (v1-core::REQ-013/AC-04).
            let rows = try recognizedText(in: content)
            #expect(rows.contains("EN"))
            #expect(rows.contains("English"))
            #expect(rows.contains("JA"))

            let list = try #require(table)
            let row = list.rect(ofRow: 0)
            try press(popover, at: list.convert(NSPoint(x: row.minX + 60, y: row.midY), to: nil))

            try waitUntil { changes == ["en"] }
            try waitUntil { popoverCount() == before }
        }
    }
}
