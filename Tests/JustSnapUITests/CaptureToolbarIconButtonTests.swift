import AppKit
import SwiftUI
import Testing
import JustSnapCore
@testable import JustSnapUI

// The toolbar's icon buttons (v1-core::REQ-008, REQ-009): Copy, Save and Close. Positions come from the
// toolbar's fixed geometry — padding 3 pt, 25 pt boxes, 3 pt gaps — counted from the right end.
@Suite("Capture toolbar icon buttons", .serialized)
@MainActor
struct CaptureToolbarIconButtonTests {
    @Test("an icon button answers a press anywhere in its box, not only on the icon's strokes")
    func iconButtonsAnswerAnywhereInTheirBox() throws {
        let presses = PressLog()
        let window = try toolbarWindow(presses)
        defer { window.orderOut(nil) }
        for (index, name) in ["close", "save", "copy"].enumerated() {
            let center = boxCenter(window, fromEnd: index)
            // Inside the 25 pt box, clear of the 13 pt icon.
            try press(window, at: NSPoint(x: center.x + 10, y: center.y + 10))
            #expect(presses.names.last == name, "\(name)")
        }
        #expect(presses.names == ["close", "save", "copy"])
    }

    @Test("an operation button that is not selected answers a press in its padding")
    func unselectedOperationButtonAnswersInPadding() throws {
        let presses = PressLog()
        let state = CaptureToolbarState(targetLanguageCode: "en")
        state.currentOperation = .translate
        let window = try toolbarWindow(presses, state: state)
        defer { window.orderOut(nil) }
        // Extract is the first control: 3 pt toolbar padding, then 9 pt of the button's own padding.
        let midY = try #require(window.contentView).bounds.midY
        try press(window, at: NSPoint(x: 6, y: midY))
        #expect(presses.names == ["extract"])
    }

    @Test("the left part of the combined button translates and the right part opens the language list")
    func translateControlHasTwoParts() throws {
        let presses = PressLog()
        let window = try toolbarWindow(presses, state: CaptureToolbarState(targetLanguageCode: "zh-Hans"))
        defer { window.orderOut(nil) }
        let right = translateControlRightEdge(window)
        let midY = try #require(window.contentView).bounds.midY
        let before = popoverCount()

        try press(window, at: NSPoint(x: right - 8, y: midY))
        #expect(presses.names.isEmpty)
        try waitUntil { popoverCount() > before }
        // The list opens and closes without animation (v1-core::REQ-013/AC-04): it goes through the unanimated presenter.
        let presenters = unanimatedPopoverControllers(in: try #require(window.contentView))
        #expect(presenters.count == 1)
        #expect(presenters.allSatisfy { $0.isShown && !$0.popover.animates })
        closePopovers()

        try press(window, at: NSPoint(x: right - 70, y: midY))
        #expect(presses.names == ["translate"])
    }

    @Test("during a request only cancel, the language and the running operation take a press")
    func requestDisablesOtherActions() throws {
        let presses = PressLog()
        let state = CaptureToolbarState(targetLanguageCode: "en")
        state.currentOperation = .translate
        state.isRequestRunning = true
        let window = try toolbarWindow(presses, state: state)
        defer { window.orderOut(nil) }
        let midY = try #require(window.contentView).bounds.midY
        let right = translateControlRightEdge(window)

        try press(window, at: NSPoint(x: 8, y: midY))
        #expect(presses.names.isEmpty)
        for index in [1, 2] {
            let center = boxCenter(window, fromEnd: index)
            try press(window, at: center)
        }
        #expect(presses.names.isEmpty)

        try press(window, at: NSPoint(x: right - 70, y: midY))
        #expect(presses.names == ["translate"], "the running operation takes it; the application then ignores it")

        let before = popoverCount()
        try press(window, at: NSPoint(x: right - 8, y: midY))
        try waitUntil { popoverCount() > before }
        closePopovers()

        let cancel = boxCenter(window, fromEnd: 0)
        try press(window, at: cancel)
        #expect(presses.names == ["translate", "close"])
    }

    @Test("a row of the language list shows its abbreviation and name, and a press sets the language and closes the list")
    func languageRowSetsLanguage() throws {
        let presses = PressLog()
        let state = CaptureToolbarState(targetLanguageCode: "en")
        let window = try toolbarWindow(presses, state: state)
        defer { window.orderOut(nil) }
        defer { closePopovers() }
        let before = popoverCount()
        try press(window, at: NSPoint(x: translateControlRightEdge(window) - 8, y: try #require(window.contentView).bounds.midY))
        try waitUntil { popoverCount() > before }
        let popover = try #require(NSApp.windows.first { $0.className.contains("Popover") && $0.isVisible })
        let rows = try recognizedListText(
            options: [
                TargetLanguageOption(code: "en", name: "English"),
                TargetLanguageOption(code: "zh-Hans", name: "Chinese"),
            ],
            selectedCode: "en"
        )
        #expect(rows.contains("EN"))
        #expect(rows.contains("English"))
        #expect(rows.contains("ZH"))

        try press(popover, at: try languageRowPoint(in: popover, row: 1))

        try waitUntil { state.targetLanguageCode == "zh-Hans" }
        #expect(presses.names == ["language zh-Hans"])
        try waitUntil { popoverCount() == before }
    }

    @Test("the language list has one row for each language and no search box")
    func languageListIsPlainRowsWithoutSearch() throws {
        let languages = TargetLanguageCatalog.standard.codes.map { TargetLanguageOption(code: $0, name: "Language \($0)") }
        let presses = PressLog()
        let state = CaptureToolbarState(targetLanguageCode: "en")
        let window = try toolbarWindow(presses, state: state, languages: languages)
        defer { window.orderOut(nil) }
        defer { closePopovers() }
        let before = popoverCount()
        try press(window, at: NSPoint(x: translateControlRightEdge(window) - 8, y: try #require(window.contentView).bounds.midY))
        try waitUntil { popoverCount() > before }
        let popover = try #require(NSApp.windows.first { $0.className.contains("Popover") && $0.isVisible })
        let list = try languageListView(in: popover)
        list.layoutSubtreeIfNeeded()

        #expect(languages.count == 11)
        let insets = list.safeAreaInsets
        #expect(list.bounds.height == insets.top + insets.bottom + 2 * TargetLanguageListMetrics.padding
            + CGFloat(languages.count) * TargetLanguageListMetrics.rowHeight)
        #expect(!allSubviews(list).contains { ($0 as? NSTextField)?.isEditable == true })
        // The last row sits where the metrics put it: a press there picks the last language.
        try press(popover, at: try languageRowPoint(in: popover, row: languages.count - 1))
        try waitUntil { state.targetLanguageCode == "ar" }
    }

    @Test("a row shows the abbreviation before the name, and only the current language has a check mark")
    func languageRowOrderAndCheckMark() throws {
        let options = [
            TargetLanguageOption(code: "en", name: "English"),
            TargetLanguageOption(code: "zh-Hans", name: "Chinese"),
        ]
        try withRenderedLanguageList(options: options, selectedCode: "en") { view in
            let lines = try recognizedLines(in: view)
            func row(_ name: String) throws -> (text: String, box: CGRect) {
                try #require(lines.first { $0.text.contains(name) }, "\(name) among \(lines.map(\.text))")
            }
            // Text recognition may read a row as one line or as two; either way the abbreviation comes first.
            let nameLine = try row("English")
            if nameLine.text == "English" {
                let abbreviation = try #require(lines.first { $0.text == "EN" }, "among \(lines.map(\.text))").box
                #expect(abbreviation.maxX <= nameLine.box.minX, "EN \(abbreviation) English \(nameLine.box)")
                #expect(abs(abbreviation.midY - nameLine.box.midY) < 4)
            } else {
                #expect(nameLine.text.hasPrefix("EN"), "row read as \(nameLine.text)")
            }

            // The check mark is an image, so it shows as ink at the right end of the row.
            let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let scale = CGFloat(bitmap.pixelsWide) / view.bounds.width
            func hasInk(rowMidY: CGFloat) -> Bool {
                let right = view.bounds.maxX - TargetLanguageListMetrics.padding
                for x in stride(from: right - 24, to: right - 2, by: 1) {
                    for y in stride(from: rowMidY - 5, to: rowMidY + 5, by: 1) {
                        guard let color = bitmap.colorAt(x: Int(x * scale), y: Int(y * scale))?.usingColorSpace(.sRGB) else { continue }
                        if color.redComponent + color.greenComponent + color.blueComponent < 2.7 { return true }
                    }
                }
                return false
            }
            #expect(hasInk(rowMidY: nameLine.box.midY), "the current language has a check mark")
            #expect(!hasInk(rowMidY: try row("Chinese").box.midY), "another language has none")
        }
    }

    @Test("the language list is narrow, and every language's name shows in full beside the check mark")
    func languageListIsNarrowAndNamesAreNotTruncated() throws {
        #expect(TargetLanguageListMetrics.width <= 200)
        for language in [EffectiveApplicationLanguage.english, .simplifiedChinese] {
            try LocalizationTestCoordinator.withExclusiveAccess {
                JustSnapLocalization.configure(effectiveLanguage: language)
                let options = TargetLanguageCatalog.standard.codes.map {
                    TargetLanguageOption(code: $0, name: JustSnapLocalization.localizedLanguageName(for: $0))
                }
                // The longest name carries the check mark, the row that has the least room.
                let longest = try #require(options.max { $0.name.count < $1.name.count })
                try withRenderedLanguageList(options: options, selectedCode: longest.code) { view in
                    #expect(view.bounds.width == TargetLanguageListMetrics.width)
                    // The recognizer reads Chinese only when it is listed first.
                    let languages = language == .english ? ["en-US", "zh-Hans"] : ["zh-Hans", "en-US"]
                    let lines = try recognizedLines(in: view, languages: languages).map(\.text)
                    for option in options {
                        #expect(lines.contains { $0.contains(option.name) }, "\(option.name) among \(lines) (\(language))")
                    }
                }
            }
        }
    }

    // Gap: SwiftUI's hover cannot be driven from a test (a mouse-moved or mouse-entered event sent to the list's
    // hosting view never reaches `onHover`), so the rule is tested as a function and that a row takes it from
    // the pointer is checked on the installed build.
    @Test("a row under the pointer is highlighted, and a row that cannot be chosen never is")
    func rowUnderThePointerIsHighlighted() {
        let resting = TargetLanguageListRowAppearance.background(isHovered: false, isEnabled: true)
        let hovered = TargetLanguageListRowAppearance.background(isHovered: true, isEnabled: true)
        #expect(resting == Color.clear)
        #expect(hovered != resting)
        #expect(TargetLanguageListRowAppearance.background(isHovered: true, isEnabled: false) == resting)
    }

    // The hint itself appears only under a real pointer: that is checked on the installed build.
    @Test("the language part's hint names the target language in full")
    func languageHintNamesLanguage() {
        LocalizationTestCoordinator.withExclusiveAccess {
            JustSnapLocalization.configure(effectiveLanguage: .simplifiedChinese)
            #expect(JustSnapStrings.targetLanguageHint("简体中文") == "目标语言：简体中文")
        }
    }

    @Test("an operation that cannot start while a result is unsaved takes no press")
    func unavailableOperationTakesNoPress() throws {
        let presses = PressLog()
        let state = CaptureToolbarState(targetLanguageCode: "en")
        state.currentOperation = .translate
        state.unavailableOperations = [.extract]
        let window = try toolbarWindow(presses, state: state)
        defer { window.orderOut(nil) }
        let midY = try #require(window.contentView).bounds.midY

        try press(window, at: NSPoint(x: 8, y: midY))
        #expect(presses.names.isEmpty)
        try press(window, at: boxCenter(window, fromEnd: 2))
        #expect(presses.names == ["copy"])
    }

    @Test("a Translate that would have to wait takes no press, though its language part still does")
    func blockedTranslateTakesNoPress() throws {
        let unsaved = CaptureToolbarState(targetLanguageCode: "en")
        unsaved.currentOperation = .extract
        unsaved.unavailableOperations = [.translate]
        let running = CaptureToolbarState(targetLanguageCode: "en")
        running.currentOperation = .extract
        running.isRequestRunning = true
        for state in [unsaved, running] {
            let presses = PressLog()
            let window = try toolbarWindow(presses, state: state)
            defer { window.orderOut(nil) }
            let right = translateControlRightEdge(window)
            let midY = try #require(window.contentView).bounds.midY

            try press(window, at: NSPoint(x: right - 70, y: midY))
            #expect(presses.names.isEmpty)

            let before = popoverCount()
            try press(window, at: NSPoint(x: right - 8, y: midY))
            try waitUntil { popoverCount() > before }
            closePopovers()
        }
    }

    @Test("Extract, Copy and Save look unavailable during another operation's request, and Extract while it would have to wait")
    func blockedControlsLookUnavailable() throws {
        func strengths(_ state: CaptureToolbarState) throws -> (extract: CGFloat, copy: CGFloat, save: CGFloat) {
            let window = try toolbarWindow(PressLog(), state: state)
            defer { window.orderOut(nil) }
            let view = try #require(window.contentView)
            // Extract's icon and the start of its label.
            let extract = CGRect(x: 14, y: view.bounds.midY - 6, width: 26, height: 12)
            return (
                try inkContrast(in: view, box: extract),
                try inkContrast(in: view, box: boxRect(window, fromEnd: 2).insetBy(dx: 4, dy: 4)),
                try inkContrast(in: view, box: boxRect(window, fromEnd: 1).insetBy(dx: 4, dy: 4))
            )
        }
        let available = try strengths(CaptureToolbarState(targetLanguageCode: "en"))
        let running = CaptureToolbarState(targetLanguageCode: "en")
        running.currentOperation = .translate
        running.isRequestRunning = true
        let duringRequest = try strengths(running)
        let unsaved = CaptureToolbarState(targetLanguageCode: "en")
        unsaved.unavailableOperations = [.extract]
        let whileUnsaved = try strengths(unsaved)

        #expect(available.extract - duringRequest.extract > 0.2, "\(available.extract), \(duringRequest.extract)")
        #expect(available.copy - duringRequest.copy > 0.2, "\(available.copy), \(duringRequest.copy)")
        #expect(available.save - duringRequest.save > 0.2, "\(available.save), \(duringRequest.save)")
        #expect(available.extract - whileUnsaved.extract > 0.2, "\(available.extract), \(whileUnsaved.extract)")
        #expect(abs(available.copy - whileUnsaved.copy) < 0.05, "Copy stays available while a result is unsaved")
    }

    @Test("the operation whose result box is showing looks selected, and only then")
    func currentOperationLooksSelected() throws {
        let state = CaptureToolbarState(targetLanguageCode: "en")
        let window = try toolbarWindow(PressLog(), state: state)
        defer { window.orderOut(nil) }
        let view = try #require(window.contentView)
        let point = NSPoint(x: 5, y: view.bounds.midY)
        let plain = try renderedColor(view, at: point)
        state.currentOperation = .extract
        try waitUntil { (try? renderedColor(view, at: point)) != plain }
        state.currentOperation = nil
        try waitUntil { (try? renderedColor(view, at: point)) == plain }

        // Above the labels, in both parts of the combined button.
        let right = translateControlRightEdge(window)
        let translatePart = NSPoint(x: right - 70, y: view.bounds.midY + 10)
        let languagePart = NSPoint(x: right - 4, y: view.bounds.midY + 10)
        let plainTranslate = try renderedColor(view, at: translatePart)
        let plainLanguage = try renderedColor(view, at: languagePart)
        state.currentOperation = .translate
        try waitUntil { (try? renderedColor(view, at: translatePart)) != plainTranslate }
        try waitUntil { (try? renderedColor(view, at: languagePart)) != plainLanguage }
        #expect(try renderedColor(view, at: point) == plain, "Extract does not look selected with it")
        state.currentOperation = .extract
        try waitUntil { (try? renderedColor(view, at: translatePart)) == plainTranslate }
        try waitUntil { (try? renderedColor(view, at: languagePart)) == plainLanguage }
    }

    @Test("the toolbar shows no Provider or model")
    func toolbarShowsNoProviderOrModel() throws {
        let hosting = NSHostingView(rootView: toolbar(state: CaptureToolbarState(targetLanguageCode: "zh-Hans"), presses: PressLog()))
        // Extract, Translate and the abbreviation with its chevron, then Copy, Save and Close, without a model label.
        #expect(hosting.fittingSize.width < 300, "width \(hosting.fittingSize.width)")
    }

    // The Copy symbol is 13 pt wide and 16 pt tall at the toolbar's 13 pt symbol size; a square is
    // 11.5 pt (measured 2026-10-29). The floppy disk matches Copy's width so the two read as one size.
    // Rendered at a fixed 2 px per point, and the outline's anti-aliased edge counts as ink, so the result
    // does not depend on the machine's display scale or how its renderer shades a thin stroke's edge
    // (CI measured the 1.2 pt outline 2 pt narrower than this Mac when only dark pixels counted).
    @Test("the save icon is a square as wide as the copy icon next to it")
    func saveIconMatchesCopyIconWidth() throws {
        let window = try toolbarWindow(PressLog())
        defer { window.orderOut(nil) }
        let view = try #require(window.contentView)
        let scale: CGFloat = 2
        let representation = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(view.bounds.width * scale), pixelsHigh: Int(view.bounds.height * scale),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        representation.size = view.bounds.size
        view.cacheDisplay(in: view.bounds, to: representation)
        let copy = try inkBounds(representation, view: view, box: boxRect(window, fromEnd: 2))
        let save = try inkBounds(representation, view: view, box: boxRect(window, fromEnd: 1))
        #expect(abs(save.width - copy.width) <= 1, "save \(save) copy \(copy)")
        #expect(abs(save.height - save.width) <= 1, "save \(save)")
    }
}

@MainActor
private final class PressLog {
    var names: [String] = []
}

@MainActor
private func toolbar(
    state: CaptureToolbarState,
    presses: PressLog,
    languages: [TargetLanguageOption] = [
        TargetLanguageOption(code: "en", name: "English"),
        TargetLanguageOption(code: "zh-Hans", name: "简体中文"),
    ]
) -> CaptureOperationToolbar {
    CaptureOperationToolbar(
        state: state,
        targetLanguages: languages,
        onStart: { presses.names.append($0 == .extract ? "extract" : "translate") },
        onTargetLanguageChange: { presses.names.append("language \($0)") },
        onCopy: { presses.names.append("copy") },
        onSave: { presses.names.append("save") },
        onCancel: { presses.names.append("close") }
    )
}

/// The combined button's right edge: padding, three icon boxes, their gaps, the 1 pt divider and its gaps.
@MainActor
private func translateControlRightEdge(_ window: NSWindow) -> CGFloat {
    let bounds = window.contentView?.bounds ?? .zero
    let size = JustSnapUIConstants.toolbarControlHeight
    let gap = JustSnapUIConstants.toolbarControlGap
    return bounds.maxX - JustSnapUIConstants.toolbarPadding - 3 * size - 3 * gap - 1 - gap
}

@MainActor
private func renderedColor(_ view: NSView, at point: NSPoint) throws -> [CGFloat] {
    view.layoutSubtreeIfNeeded()
    let representation = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
    view.cacheDisplay(in: view.bounds, to: representation)
    let scale = CGFloat(representation.pixelsWide) / view.bounds.width
    let color = try #require(representation.colorAt(
        x: Int(point.x * scale),
        y: Int((view.bounds.height - point.y) * scale)
    )?.usingColorSpace(.sRGB))
    return [color.redComponent, color.greenComponent, color.blueComponent]
}

@MainActor
private func toolbarWindow(
    _ presses: PressLog,
    state: CaptureToolbarState = CaptureToolbarState(targetLanguageCode: "en"),
    languages: [TargetLanguageOption]? = nil
) throws -> NSWindow {
    let root = languages.map { toolbar(state: state, presses: presses, languages: $0) }
        ?? toolbar(state: state, presses: presses)
    let hosting = NSHostingView(rootView: root)
    hosting.frame = CGRect(origin: .zero, size: hosting.fittingSize)
    let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = hosting
    window.appearance = NSAppearance(named: .aqua)
    window.orderFrontRegardless()
    hosting.layoutSubtreeIfNeeded()
    return window
}

@MainActor
private func boxRect(_ window: NSWindow, fromEnd index: Int) -> CGRect {
    let bounds = window.contentView?.bounds ?? .zero
    let size = JustSnapUIConstants.toolbarControlHeight
    let maxX = bounds.maxX - JustSnapUIConstants.toolbarPadding
        - CGFloat(index) * (size + JustSnapUIConstants.toolbarControlGap)
    return CGRect(x: maxX - size, y: bounds.midY - size / 2, width: size, height: size)
}

@MainActor
private func boxCenter(_ window: NSWindow, fromEnd index: Int) -> NSPoint {
    let box = boxRect(window, fromEnd: index)
    return NSPoint(x: box.midX, y: box.midY)
}

/// Bounds, in points, of the icon pixels inside a box of the rendered toolbar (light appearance): any pixel
/// clearly darker than the light background, so an outline's anti-aliased edge counts.
@MainActor
private func inkBounds(_ representation: NSBitmapImageRep, view: NSView, box: CGRect) throws -> CGRect {
    let scale = CGFloat(representation.pixelsWide) / view.bounds.width
    var minX = Int.max, minY = Int.max, maxX = Int.min, maxY = Int.min
    // Bitmap rows count from the top.
    let rows = Int((view.bounds.height - box.maxY) * scale)..<Int((view.bounds.height - box.minY) * scale)
    let columns = Int(box.minX * scale)..<Int(box.maxX * scale)
    for y in rows {
        for x in columns {
            guard let color = representation.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
                  color.alphaComponent > 0.5,
                  (color.redComponent + color.greenComponent + color.blueComponent) / 3 < 0.8 else { continue }
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        }
    }
    try #require(minX <= maxX, "no icon pixels in \(box)")
    return CGRect(x: CGFloat(minX) / scale, y: CGFloat(minY) / scale,
                  width: CGFloat(maxX - minX + 1) / scale, height: CGFloat(maxY - minY + 1) / scale)
}

