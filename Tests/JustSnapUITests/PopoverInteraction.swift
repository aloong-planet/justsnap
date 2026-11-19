import AppKit
import Testing

// Pressing controls and reading the language list's popover, shared by the toolbar and menu panel tests.

@MainActor
func closePopovers() {
    for popover in NSApp.windows where popover.className.contains("Popover") && popover.isVisible {
        popover.orderOut(nil)
    }
}

@MainActor
func allSubviews(_ view: NSView) -> [NSView] {
    [view] + view.subviews.flatMap(allSubviews)
}

@MainActor
func popoverCount() -> Int {
    NSApp.windows.filter { $0.className.contains("Popover") && $0.isVisible }.count
}

@MainActor
func waitUntil(_ condition: () -> Bool) throws {
    let deadline = Date().addingTimeInterval(2)
    while !condition(), Date() < deadline {
        _ = RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
    }
    try #require(condition())
}

@MainActor
func press(_ window: NSWindow, at point: NSPoint) throws {
    for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
        window.sendEvent(try #require(NSEvent.mouseEvent(
            with: type, location: point, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil,
            eventNumber: 1, clickCount: 1, pressure: 1
        )))
    }
}
