import AppKit
import SwiftUI
import Testing
@testable import JustSnapUI

// v1-core::REQ-013/AC-04. The language list opens and closes without a show or hide animation. SwiftUI's
// `.popover` gives no handle on its popover, so the lists are presented through `UnanimatedPopoverController`;
// the toolbar and menu panel tests check that their lists use it. Gap: the result box title menu has no popover
// test (it needs a model result on screen), so nothing fails if it goes back to the animated popover; retest
// with the installed build.
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

    @Test("the binding opens the list, a press outside it resets the binding, and the list opens again from the next press")
    func bindingFollowsOutsideClose() throws {
        let model = PopoverModel()
        let hosting = NSHostingView(rootView: PopoverHost(model: model))
        hosting.frame = NSRect(x: 0, y: 0, width: 200, height: 60)
        let window = NSWindow(contentRect: hosting.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        defer { closePopovers() }
        hosting.layoutSubtreeIfNeeded()
        let before = popoverCount()
        let presenter = try #require(unanimatedPopoverControllers(in: hosting).first)

        model.isPresented = true
        try waitUntil { popoverCount() == before + 1 }

        // What a press outside a transient popover does; the binding must follow it, or the next press on the
        // button toggles it from true to false and the list does not open.
        presenter.popover.performClose(nil)
        try waitUntil { popoverCount() == before }
        try waitUntil { !model.isPresented }
        // Let the view see the binding false before it goes true again; a press is never in the same turn.
        settle()

        model.isPresented = true
        try waitUntil { popoverCount() == before + 1 }
        model.isPresented = false
        try waitUntil { popoverCount() == before }
    }
}

@MainActor
private func settle() {
    let deadline = Date().addingTimeInterval(0.1)
    while Date() < deadline {
        _ = RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
    }
}

private final class PopoverModel: ObservableObject {
    @Published var isPresented = false
}

private struct PopoverHost: View {
    @ObservedObject var model: PopoverModel

    var body: some View {
        Color.clear
            .frame(width: 80, height: 24)
            .unanimatedPopover(isPresented: $model.isPresented) { Text("list").padding() }
    }
}
