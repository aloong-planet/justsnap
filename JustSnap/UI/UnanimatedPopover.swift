import AppKit
import SwiftUI

/// Presents SwiftUI content in an `NSPopover` that opens and closes without animation. SwiftUI's `.popover`
/// gives no handle on its popover, so the animation cannot be turned off there. Like SwiftUI's popover it is
/// a transient child window of the anchor's window, so a press in it counts as inside that window's panel.
@MainActor
final class UnanimatedPopoverController: NSObject, NSPopoverDelegate {
    let popover = NSPopover()
    /// Called once the popover is closed, whether by `dismiss()` or by a press outside it.
    var onClose: (() -> Void)?
    private var hosting: NSHostingController<AnyView>?

    override init() {
        super.init()
        popover.animates = false
        popover.behavior = .transient
        popover.delegate = self
    }

    var isShown: Bool { popover.isShown }

    func present<Content: View>(_ content: Content, relativeTo anchor: NSView, preferredEdge: NSRectEdge) {
        update(content)
        guard !popover.isShown, anchor.window != nil else { return }
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: preferredEdge)
    }

    /// Replaces what the popover shows while it is open, or the next time it opens.
    func update<Content: View>(_ content: Content) {
        if let hosting {
            hosting.rootView = AnyView(content)
        } else {
            let hosting = NSHostingController(rootView: AnyView(content))
            hosting.sizingOptions = .preferredContentSize
            popover.contentViewController = hosting
            self.hosting = hosting
        }
    }

    func dismiss() {
        guard popover.isShown else { return }
        popover.close()
    }

    nonisolated func popoverDidClose(_ notification: Notification) {
        MainActor.assumeIsolated { onClose?() }
    }
}

private struct UnanimatedPopoverAnchor<Content: View>: NSViewRepresentable {
    @Binding var isPresented: Bool
    let preferredEdge: NSRectEdge
    let content: Content

    func makeCoordinator() -> UnanimatedPopoverController { UnanimatedPopoverController() }

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ anchor: NSView, context: Context) {
        let controller = context.coordinator
        let isPresented = $isPresented
        controller.onClose = { if isPresented.wrappedValue { isPresented.wrappedValue = false } }
        if self.isPresented {
            controller.present(content, relativeTo: anchor, preferredEdge: preferredEdge)
        } else {
            controller.dismiss()
        }
    }

    static func dismantleNSView(_ anchor: NSView, coordinator: UnanimatedPopoverController) {
        coordinator.onClose = nil
        coordinator.dismiss()
    }
}

extension View {
    /// `.popover(isPresented:arrowEdge: .bottom)` without the show and hide animation: the popover opens
    /// below the view.
    func unanimatedPopover<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        background(UnanimatedPopoverAnchor(isPresented: isPresented, preferredEdge: .minY, content: content()))
    }
}
