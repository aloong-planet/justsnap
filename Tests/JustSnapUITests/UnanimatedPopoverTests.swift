import AppKit
import SwiftUI
import Testing
@testable import JustSnapUI

// v1-core::REQ-013/AC-04. The language list opens and closes without a show or hide animation. SwiftUI's
// `.popover` gives no handle on its popover, so the lists are presented through `UnanimatedPopoverController`;
// the three surfaces' own popover tests keep covering that each one opens its list and closes it on a choice.
@Suite("Unanimated popover", .serialized)
@MainActor
struct UnanimatedPopoverTests {
    @Test("the popover has no animation, so closing it takes it off screen at once")
    func closesAtOnce() throws {
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 300, height: 200), styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let anchor = NSView(frame: NSRect(x: 20, y: 20, width: 80, height: 24))
        window.contentView?.addSubview(anchor)
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        defer { closePopovers() }
        let before = popoverCount()
        let controller = UnanimatedPopoverController()
        var closed = 0
        controller.onClose = { closed += 1 }

        controller.present(Text("list").padding(), relativeTo: anchor, preferredEdge: .minY)
        try waitUntil { popoverCount() == before + 1 }
        #expect(controller.popover.animates == false)
        #expect(window.childWindows?.contains { $0.className.contains("Popover") } == true, "a child window of the anchor's window")

        controller.dismiss()
        // With an animation the popover's window stays on screen while it fades out.
        #expect(popoverCount() == before)
        #expect(!controller.popover.isShown)
        #expect(closed == 1)
    }
}
