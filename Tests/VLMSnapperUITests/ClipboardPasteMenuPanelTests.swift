import AppKit
import SwiftUI
import Testing
import VLMSnapperCore
@testable import VLMSnapperUI

// clipboard-paste::REQ-001/AC-01. The shortcut texts and icons, including the Paste button showing no shortcut
// while the paste shortcut is unset (AC-04), are checked on screenshots of the installed build: in this test
// host the panel's SwiftUI text has no accessibility labels to read, even after a second's settling.
@Suite("Clipboard paste menu panel", .serialized)
@MainActor
struct ClipboardPasteMenuPanelTests {
    @Test("Capture takes the left half of the row and Paste the right half")
    func captureAndPasteSplitTheRow() throws {
        var pressed: [String] = []
        let hostingView = NSHostingView(rootView: MenuBarPanelView(
            recentItems: [],
            onCapture: { pressed.append("capture") },
            onPaste: { pressed.append("paste") },
            onOpenRecent: { _ in },
            onNavigate: { _ in },
            onCheckUpdates: {}
        ))
        hostingView.frame = NSRect(x: 0, y: 0, width: MenuBarPanelMetrics.width, height: 420)
        let window = NSWindow(contentRect: hostingView.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = hostingView
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        hostingView.layoutSubtreeIfNeeded()
        // The row sits under the 50-point title; buttons are 36 points tall, with 10 points on each side.
        let rowY = hostingView.bounds.maxY - 50 - MenuBarPanelMetrics.captureButtonHeight / 2

        for x in [12.0, 144, 156, 288] {
            try click(window, at: NSPoint(x: x, y: rowY))
        }

        #expect(pressed == ["capture", "capture", "paste", "paste"])
    }

    private func click(_ window: NSWindow, at point: NSPoint) throws {
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            window.sendEvent(try #require(NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1
            )))
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.02))
    }
}
