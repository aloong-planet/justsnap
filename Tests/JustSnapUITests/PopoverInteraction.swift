import AppKit
import Testing
import SwiftUI
@testable import JustSnapUI

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

/// The view that holds the language list inside an open popover, once it has its size.
@MainActor
func languageListView(in popover: NSWindow) throws -> NSView {
    var list: NSView?
    try waitUntil {
        list = popover.contentView.flatMap { allSubviews($0).first { $0.className.contains("HostingView") } }
        list?.layoutSubtreeIfNeeded()
        return (list?.bounds.height ?? 0) > 0
    }
    return try #require(list)
}

/// Where a language's row renders, as a point in the popover's window: the rows stack from the list's top
/// at a fixed height (`TargetLanguageListMetrics`).
@MainActor
func languageRowPoint(in popover: NSWindow, row: Int) throws -> NSPoint {
    let list = try languageListView(in: popover)
    // The popover insets its content from the frame view's edge.
    let top = list.safeAreaInsets.top + TargetLanguageListMetrics.padding
        + (CGFloat(row) + 0.5) * TargetLanguageListMetrics.rowHeight
    let y = list.isFlipped ? top : list.bounds.height - top
    return list.convert(NSPoint(x: list.bounds.midX, y: y), to: nil)
}

/// The text the language list renders. The list is drawn in a window of its own: the content of an open
/// popover renders to nothing when read back from the process.
@MainActor
func recognizedListText(options: [TargetLanguageOption], selectedCode: String) throws -> String {
    let hosting = NSHostingView(rootView: TargetLanguageList(options: options, selectedCode: selectedCode) { _ in }
        .background(Color.white))
    hosting.frame = CGRect(origin: .zero, size: hosting.fittingSize)
    let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = hosting
    window.appearance = NSAppearance(named: .aqua)
    window.orderFrontRegardless()
    defer { window.orderOut(nil) }
    return try recognizedText(in: hosting)
}
