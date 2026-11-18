import AppKit
import Foundation
import ImageIO
import SQLite3
import SwiftUI
import Testing
import UniformTypeIdentifiers
import VLMSnapperCore
import VLMSnapperUI
@testable import VLMSnapperApp

// clipboard-paste. The paste fixture's pasteboard is a private one the real reader reads; its layouts copy
// clipboards seen on this Mac on 2026-11-17 (WebKit's Copy Image) and 2026-11-18 (a Finder file copy). Not covered here, because they need the
// window server and other apps: what browsers other than WebKit and spreadsheets put on the clipboard,
// that showing the box leaves another app active, that a click makes it key, the box's level above other
// apps' windows, and the delegate closing the real menu panel — checked on the installed build.
// Also not covered: an oversized paste (REQ-004/AC-04) at app level. The app fixture cannot make Gemini, the only
// Provider checked before sending, the current Provider: its HTTP fake serves only DeepSeek's model-list shape, and
// a Gemini configuration stored before launch comes back with no models and no selection. Covering it needs a
// Gemini model-list response taken from a real one and the request-body limit injectable through the app's
// dependencies. The box presentation tests cover the message and the Core runner tests the sizes; nothing covers
// this controller passing the paste wording, the Provider's name and the sizes into the box. The display the box opens on and its default place (REQ-005/AC-01) need a second display
// and a placed pointer, and the paste shortcut recorder sitting below the capture one (REQ-001/AC-03) is layout;
// both are checked on the installed build. Retry with no Provider or model left (the missing-selection failure)
// needs the current Provider removed while the box is open and is not driven here. The box showing that the
// request is being prepared while a large image converts (failure mode 4) depends on conversion timing. A history database that cannot record (REQ-002/AC-05) goes
// through the same runner as a capture, so it is not repeated here.
extension ProviderApplicationTests {
    @Test
    func pastingACopiedImageExtractsItInAFloatingBox() async throws {
        try await withResultFixture { fixture, model in
            let source = try pastedImage(width: 30, height: 20)
            putWebKitCopiedImage(source, on: fixture.pasteboard)

            model.pasteFromClipboard()
            try await eventually { await fixture.http.imageRequests.count == 1 }
            try await eventually { resultBoxPresentation()?.title == "Extract" }

            #expect(try mainScreenOverlay() == nil)
            #expect(resultBoxPresentation()?.showsOperations == true)
            #expect(resultBox()?.level == .floating)
            try await fixture.http.finishImage(source: "Pasted text")
            try await eventually { resultBoxText() == "Pasted text" }
            try await eventually { model.historyRecords.count == 1 }

            let record = try #require(model.historyRecords.first)
            let saved = try Data(contentsOf: URL(fileURLWithPath: record.operation.screenshot!.path))
            let sent = try #require(await fixture.http.imageRequests.first.flatMap(sentPNG))
            #expect(sent == saved)
            let size = try pngSize(saved)
            #expect(size.width == 30 && size.height == 20)
        }
    }

    @Test
    func pastingCopiedTextExtractsItWithoutAnImageOrFile() async throws {
        try await withResultFixture { fixture, model in
            let text = "  A paragraph of copied\ntext that wraps 'here'.\n"
            fixture.pasteboard.clearContents()
            fixture.pasteboard.setString(text, forType: .string)

            model.pasteFromClipboard()
            try await eventually { await fixture.http.imageRequests.count == 1 }
            try await eventually { resultBoxPresentation()?.title == "Extract" }

            let request = try #require(await fixture.http.imageRequests.first)
            #expect(sentUserText(request) == text)
            #expect(sentPNG(request) == nil)
            #expect(resultBoxPresentation()?.showsOperations == true)
            // The box knows its input is text, so an oversized request asks for less text (REQ-007/AC-03).
            #expect(resultBoxPresentation()?.source == .pastedText)
            try await fixture.http.finishImage(source: "A paragraph of copied text that wraps 'here'.")
            try await eventually { resultBoxText() == "A paragraph of copied text that wraps 'here'." }
            try await eventually { model.historyRecords.first?.operation.status == .succeeded }
            #expect(model.historyRecords.map(\.operation.input) == [.pastedText(text)])
            #expect(try managedFiles(in: fixture).isEmpty)
        }
    }

    @Test
    func aCopiedFinderFileIsReportedWithoutARequestOrRecord() async throws {
        try await withResultFixture { fixture, model in
            putFinderCopiedFile(named: "report.pdf", on: fixture.pasteboard)

            model.pasteFromClipboard()
            try await eventually { resultBoxPresentation()?.title == "Paste" }

            #expect(resultBoxPresentation()?.body == .message("Files can't be pasted for now. Copy text or an image instead."))
            #expect(resultBoxPresentation()?.canRetry == false)
            #expect(resultBoxPresentation()?.showsOperations == false)
            await settleMainActor()
            #expect(await fixture.http.imageRequests.isEmpty)
            #expect(model.historyRecords.isEmpty)
            #expect(try managedFiles(in: fixture).isEmpty)
        }
    }

    @Test
    func translateAfterATextPasteMakesItsOwnRecordFromTheSameText() async throws {
        try await withResultFixture { fixture, model in
            model.changeTargetLanguage("ja")
            fixture.pasteboard.clearContents()
            fixture.pasteboard.setString("Hello there.\nSecond line.", forType: .string)
            model.pasteFromClipboard()
            try await eventually { await fixture.http.imageRequests.count == 1 }
            try await fixture.http.finishImage(source: "Hello there. Second line.")
            try await eventually { model.historyRecords.count == 1 }

            // A later clipboard change does not reach the operations of this paste (clipboard-paste::REQ-003/AC-07).
            fixture.pasteboard.clearContents()
            fixture.pasteboard.setString("Copied since", forType: .string)
            try #require(pasteBoxOperations()).onStart(.translate)
            try await eventually { await fixture.http.imageRequests.count == 2 }
            let request = try #require(await fixture.http.imageRequests.last)
            #expect(sentUserText(request) == "Hello there.\nSecond line.")
            try await fixture.http.finishImage(source: "Hello there.", translation: "こんにちは。")
            try await eventually { model.historyRecords.count == 2 }

            let records = model.historyRecords
            #expect(records.allSatisfy { $0.operation.input == .pastedText("Hello there.\nSecond line.") })
            #expect(records.contains { $0.operation.kind == .translate && $0.operation.targetLanguage == "ja" })
            #expect(fixture.clipboardReader.reads == 1)
        }
    }

    @Test
    func withoutAModelPasteShowsOnboardingAndLeavesTheClipboardUnread() async throws {
        try await withFixture { fixture in
            try await fixture.withModel { model in
                var onboardingRequests = 0
                model.onShowOnboarding = { onboardingRequests += 1 }
                putWebKitCopiedImage(try pastedImage(width: 8, height: 8), on: fixture.pasteboard)

                model.pasteFromClipboard()
                try await eventually { onboardingRequests == 1 }

                #expect(fixture.clipboardReader.reads == 0)
                #expect(resultBox() == nil)
            }
        }
    }

    @Test
    func pasteNeedsNoScreenRecordingPermission() async throws {
        try await withFixture { fixture in
            fixture.permissionGranted = false
            await fixture.http.allowImageRequests()
            try await fixture.withModel { model in
                try await makeCaptureReady(model, key: "fixture-paste-key")
                putWebKitCopiedImage(try pastedImage(width: 8, height: 8), on: fixture.pasteboard)

                model.pasteFromClipboard()
                try await eventually { await fixture.http.imageRequests.count == 1 }
                try await fixture.http.finishImage(source: "Done")
                try await eventually { model.historyRecords.first?.operation.status == .succeeded }
            }
        }
    }

    @Test
    func duringACredentialJobPasteShowsTheProviderPageAndLeavesTheClipboardUnread() async throws {
        try await withFixture { fixture in
            try await fixture.withModel { model in
                try await makeCaptureReady(model, key: "fixture-initial-key")
                await fixture.http.pause()
                model.credentialEditor.edit("fixture-replacement-key")
                #expect(model.credentialEditor.submit(for: .deepSeek, isReadOnly: false,
                    operation: model.providerSettingsConfiguration().onValidate))
                try await eventually { await fixture.http.requests.count == 2 }
                var providerNavigations = 0
                model.onNavigate = { if $0 == .providerSettings { providerNavigations += 1 } }

                model.pasteFromClipboard()
                try await eventually { providerNavigations == 1 }

                #expect(fixture.clipboardReader.reads == 0)
                #expect(resultBox() == nil)
                await fixture.http.release()
                try await eventually { !model.credentialEditor.isSubmitting }
            }
        }
    }

    @Test
    func pasteDoesNothingWhileTheCaptureInterfaceIsOpen() async throws {
        try await withResultFixture { fixture, model in
            putWebKitCopiedImage(try pastedImage(width: 8, height: 8), on: fixture.pasteboard)
            let (overlay, _) = try await completeSelection(fixture)

            model.pasteFromClipboard()
            await settleMainActor()

            #expect(fixture.clipboardReader.reads == 0)
            #expect(resultBox() == nil)
            try pressEscape(overlay)
            try await eventually { try mainScreenOverlay() == nil }
        }
    }

    @Test
    func whileAPasteRequestRunsNeitherPasteNorCaptureDoesAnything() async throws {
        try await withResultFixture { fixture, model in
            putWebKitCopiedImage(try pastedImage(width: 8, height: 8), on: fixture.pasteboard)
            model.pasteFromClipboard()
            try await eventually { await fixture.http.imageRequests.count == 1 }

            model.pasteFromClipboard()
            try fixture.shortcuts.fire()
            await settleMainActor()

            #expect(fixture.clipboardReader.reads == 1)
            #expect(await fixture.capture.requests == 0)
            #expect(try mainScreenOverlay() == nil)
            #expect(await fixture.http.imageRequests.count == 1)
            try await fixture.http.finishImage(source: "Done")
            try await eventually { model.historyRecords.first?.operation.status == .succeeded }
        }
    }

    @Test
    func closingTheBoxDuringARequestSavesItAsCanceled() async throws {
        try await withResultFixture { fixture, model in
            putWebKitCopiedImage(try pastedImage(width: 8, height: 8), on: fixture.pasteboard)
            model.pasteFromClipboard()
            try await eventually { await fixture.http.imageRequests.count == 1 }
            let box = try #require(resultBox())

            try await clickPasteBoxButton(box, fromEnd: 0)

            try await eventually { resultBox() == nil }
            try await eventually { model.historyRecords.first?.operation.status == .canceled }
            #expect(model.providerSnapshot.activity == nil)
        }
    }

    @Test
    func closingWithAnUnsavedResultAsksOnTheBox() async throws {
        try await withResultFixture { fixture, model in
            putWebKitCopiedImage(try pastedImage(width: 8, height: 8), on: fixture.pasteboard)
            let database = try failSuccessfulSaves(fixture)
            defer { sqlite3_close(database) }
            model.pasteFromClipboard()
            try await eventually { await fixture.http.imageRequests.count == 1 }
            try await fixture.http.finishImage(source: "Unsaved text")
            try await eventually { resultBoxPresentation()?.saveNotice != nil }
            let box = try #require(resultBox())

            try await clickPasteBoxButton(box, fromEnd: 0)
            try await answerSheet(on: box, with: .alertSecondButtonReturn)
            await settleMainActor()
            #expect(resultBox() === box)
            #expect(resultBoxText() == "Unsaved text")

            // Capture and paste wait for the unsaved result (clipboard-paste::REQ-002/AC-04, REQ-005/AC-07).
            model.pasteFromClipboard()
            try fixture.shortcuts.fire()
            await settleMainActor()
            #expect(fixture.clipboardReader.reads == 1)
            #expect(await fixture.capture.requests == 0)

            try await clickPasteBoxButton(box, fromEnd: 0)
            try await answerSheet(on: box, with: .alertFirstButtonReturn)
            try await eventually { resultBox() == nil }
        }
    }

    @Test
    func aNewPasteReplacesTheIdleBoxWhereItWasDragged() async throws {
        try await withResultFixture { fixture, model in
            putWebKitCopiedImage(try pastedImage(width: 8, height: 8), on: fixture.pasteboard)
            model.pasteFromClipboard()
            try await eventually { await fixture.http.imageRequests.count == 1 }
            try await fixture.http.finishImage(source: "First")
            try await eventually { resultBoxText() == "First" }
            try await eventually { model.historyRecords.count == 1 }
            let box = try #require(resultBox())
            let placed = box.frame
            let header = NSPoint(x: 150, y: box.frame.height - CaptureResultBoxMetrics.headerHeight / 2)
            try drag(box, from: header, to: NSPoint(x: header.x - 200, y: header.y - 120))
            let dragged = box.frame
            #expect(dragged.origin != placed.origin)

            putWebKitCopiedImage(try pastedImage(width: 12, height: 6), on: fixture.pasteboard)
            model.pasteFromClipboard()
            try await eventually { await fixture.http.imageRequests.count == 2 }
            try await fixture.http.finishImage(source: "Second")
            try await eventually { resultBoxText() == "Second" }

            #expect(resultBox()?.frame == dragged)
            try await eventually { model.historyRecords.count == 2 }
            let paths = Set(model.historyRecords.map(\.operation.screenshot!.path))
            #expect(paths.count == 2)
        }
    }

    @Test
    func anUnsavedImageIsRetriedFromMemoryWhateverTheClipboardHoldsLater() async throws {
        try await withResultFixture { fixture, model in
            let folder = fixture.root.appendingPathComponent("Pictures")
            try? FileManager.default.removeItem(at: folder)
            try Data().write(to: folder)
            putWebKitCopiedImage(try pastedImage(width: 9, height: 5), on: fixture.pasteboard)

            model.pasteFromClipboard()
            try await eventually {
                guard case .failure = resultBoxPresentation()?.body else { return false }
                return resultBoxPresentation()?.canRetry == true
            }
            #expect(model.historyRecords.isEmpty)
            #expect(await fixture.http.imageRequests.isEmpty)

            try FileManager.default.removeItem(at: folder)
            fixture.pasteboard.clearContents()
            fixture.pasteboard.setString("Something copied since", forType: .string)
            try await clickPasteBoxButton(try #require(resultBox()), fromEnd: 1)
            try await eventually { await fixture.http.imageRequests.count == 1 }

            let sent = try #require(await fixture.http.imageRequests.first.flatMap(sentPNG))
            let size = try pngSize(sent)
            #expect(size.width == 9 && size.height == 5)
            #expect(fixture.clipboardReader.reads == 1)
            try await fixture.http.finishImage(source: "Saved after all")
            try await eventually { model.historyRecords.first?.operation.status == .succeeded }
        }
    }

    @Test
    func translateInTheOperationRowMakesItsOwnRecordFromTheSameFile() async throws {
        try await withResultFixture { fixture, model in
            model.changeTargetLanguage("ja")
            putWebKitCopiedImage(try pastedImage(width: 8, height: 8), on: fixture.pasteboard)
            model.pasteFromClipboard()
            try await eventually { await fixture.http.imageRequests.count == 1 }
            try await fixture.http.finishImage(source: "Source")
            try await eventually { model.historyRecords.count == 1 }
            let operations = try #require(pasteBoxOperations())
            #expect(operations.toolbarState.targetLanguageCode == "ja")

            operations.onStart(.translate)
            try await eventually { await fixture.http.imageRequests.count == 2 }
            #expect(resultBoxPresentation()?.title.hasPrefix("Translate · ") == true)
            #expect(operations.toolbarState.currentOperation == .translate)
            try await fixture.http.finishImage(source: "Source", translation: "訳文")
            try await eventually { model.historyRecords.count == 2 }

            let records = model.historyRecords
            #expect(Set(records.map(\.operation.screenshot!.path)).count == 1)
            #expect(records.contains { $0.operation.kind == .translate && $0.operation.targetLanguage == "ja" })

            // Back to Extract shows its result again without a request (clipboard-paste::REQ-006/AC-04).
            operations.onStart(.extract)
            await settleMainActor()
            #expect(resultBoxText() == "Source")
            #expect(await fixture.http.imageRequests.count == 2)

            // Copy copies the shown result (clipboard-paste::REQ-006/AC-02).
            try await clickPasteBoxButton(try #require(resultBox()), fromEnd: 2)
            #expect(fixture.clipboard.writtenTexts.last == "Source")

            // Translate after a target-language change starts a new record (clipboard-paste::REQ-006/AC-04).
            operations.onTargetLanguageChange("fr")
            operations.onStart(.translate)
            try await eventually { await fixture.http.imageRequests.count == 3 }
            try await fixture.http.finishImage(source: "Source", translation: "Traduction")
            try await eventually { model.historyRecords.count == 3 }
            #expect(model.historyRecords.contains { $0.operation.targetLanguage == "fr" })

            // Retry reruns the shown record in its own language, not the one picked since (v1-core REQ-011/AC-05).
            operations.onTargetLanguageChange("ko")
            try await eventually { resultBoxPresentation()?.canRetry == true }
            try await clickPasteBoxButton(try #require(resultBox()), fromEnd: 1)
            try await eventually { await fixture.http.imageRequests.count == 4 }
            try await fixture.http.finishImage(source: "Source", translation: "Rerun")
            try await eventually {
                model.historyRecords.contains { $0.operation.translationMarkdown?.contains("Rerun") == true }
            }
            #expect(model.historyRecords.count == 3)
            let rerun = model.historyRecords.first { $0.operation.translationMarkdown?.contains("Rerun") == true }
            #expect(rerun?.operation.targetLanguage == "fr")
        }
    }

    @Test
    func anUnsavedResultOutlastsACancelledQuitAndRetrySaveWritesIt() async throws {
        try await withResultFixture { fixture, model in
            putWebKitCopiedImage(try pastedImage(width: 8, height: 8), on: fixture.pasteboard)
            let database = try failSuccessfulSaves(fixture)
            defer { sqlite3_close(database) }
            model.pasteFromClipboard()
            try await eventually { await fixture.http.imageRequests.count == 1 }
            try await fixture.http.finishImage(source: "Unsaved text")
            try await eventually { resultBoxPresentation()?.saveNotice != nil }
            let box = try #require(resultBox())

            // Quitting asks on the box; keeping the result keeps the app running (clipboard-paste::REQ-005/AC-08).
            let quitting = Task { await model.prepareForTermination() }
            try await answerSheet(on: box, with: .alertSecondButtonReturn)
            #expect(await quitting.value == false)
            #expect(resultBox() === box)
            #expect(resultBoxText() == "Unsaved text")

            // Retry Save writes it without another request (clipboard-paste failure mode 8).
            try #require(sqlite3_exec(database, "DROP TRIGGER box_save_failure", nil, nil, nil) == SQLITE_OK)
            await settleMainActor()
            pumpNativeEvents(box)
            try click(box, at: NSPoint(x: try #require(box.contentView).bounds.maxX - 32, y: 20))
            try await eventually { resultBoxPresentation()?.saveNotice == nil }
            try await eventually {
                model.historyRecords.first?.operation.sourceMarkdown == "Unsaved text"
                    && model.historyRecords.first?.operation.status == .succeeded
            }
            #expect(await fixture.http.imageRequests.count == 1)

            // Once saved, quitting closes the box without asking.
            #expect(await model.prepareForTermination())
            #expect(resultBox() == nil)
        }
    }

    @Test
    func aCaptureClosesTheIdleBoxOnlyOnceItsFreezeFrameShows() async throws {
        try await withResultFixture { fixture, model in
            putWebKitCopiedImage(try pastedImage(width: 8, height: 8), on: fixture.pasteboard)
            model.pasteFromClipboard()
            try await eventually { await fixture.http.imageRequests.count == 1 }
            try await fixture.http.finishImage(source: "Pasted")
            try await eventually { model.historyRecords.first?.operation.status == .succeeded }
            let box = try #require(resultBox())

            // Leaving before the freeze frame shows keeps the box.
            await fixture.capture.holdFrames()
            try fixture.shortcuts.fire()
            try await eventually { try mainScreenOverlay() != nil }
            try pressEscape(try #require(try mainScreenOverlay()))
            await fixture.capture.release()
            try await eventually { try mainScreenOverlay() == nil }
            await settleMainActor()
            #expect(box.isVisible)
            #expect(resultBoxText() == "Pasted")

            try fixture.shortcuts.fire()
            let overlay = try await frozenMainOverlay()
            try await eventually { !box.isVisible }
            #expect(resultBox() == nil)
            try pressEscape(overlay)
            try await eventually { try mainScreenOverlay() == nil }
        }
    }

    @Test
    func quittingCancelsARunningPasteRequest() async throws {
        try await withResultFixture { fixture, model in
            putWebKitCopiedImage(try pastedImage(width: 8, height: 8), on: fixture.pasteboard)
            model.pasteFromClipboard()
            try await eventually { await fixture.http.imageRequests.count == 1 }

            #expect(await model.prepareForTermination())

            #expect(resultBox() == nil)
            try await eventually { model.historyRecords.first?.operation.status == .canceled }
        }
    }

    @Test
    func showingTheBoxTakesNoKeyboardFocusAndEscapeClosesIt() async throws {
        try await withResultFixture { fixture, model in
            fixture.pasteboard.clearContents()
            model.pasteFromClipboard()
            try await eventually { resultBox() != nil }
            let box = try #require(resultBox())
            pumpNativeEvents(box)

            #expect(!box.isKeyWindow)
            try pressEscape(box)
            try await eventually { resultBox() == nil }
        }
    }

    @Test
    func thePasteShortcutPastesAndCannotEqualTheCaptureShortcut() async throws {
        try await withResultFixture { fixture, model in
            #expect(model.settings.pasteShortcut == GlobalShortcut(keyCode: 9, modifiers: [.option, .shift]))
            fixture.pasteboard.clearContents()
            try fixture.shortcuts.fire(.defaultPaste)
            try await eventually { resultBoxPresentation()?.title == "Paste" }
            try await clickPasteBoxButton(try #require(resultBox()), fromEnd: 0)
            try await eventually { resultBox() == nil }

            let callbacks = model.managementCallbacks()
            callbacks.onPasteShortcutChange(.defaultCapture)
            #expect(model.settings.pasteShortcutFailure == .conflict)
            #expect(model.settings.pasteShortcut == .defaultPaste)
            #expect(fixture.shortcuts.isRegistered(.defaultPaste))
            callbacks.onShortcutChange(.defaultPaste)
            #expect(model.settings.shortcutFailure == .conflict)
            #expect(model.settings.captureShortcut == .defaultCapture)

            let replacement = GlobalShortcut(keyCode: 9, modifiers: [.command, .option])
            callbacks.onPasteShortcutChange(replacement)
            #expect(model.settings.pasteShortcutFailure == nil)
            #expect(model.settings.pasteShortcut == replacement)
            #expect(!fixture.shortcuts.isRegistered(.defaultPaste))
            try fixture.shortcuts.fire(replacement)
            try await eventually { resultBoxPresentation()?.title == "Paste" }
            try await clickPasteBoxButton(try #require(resultBox()), fromEnd: 0)
            try await eventually { resultBox() == nil }
        }
    }

    @Test
    func aSavedPasteShortcutIsRegisteredAtTheNextLaunch() async throws {
        let replacement = GlobalShortcut(keyCode: 9, modifiers: [.command, .option])
        try await withFixture { fixture in
            try await fixture.withModel { model in
                model.managementCallbacks().onPasteShortcutChange(replacement)
                #expect(model.settings.pasteShortcut == replacement)
            }
            try await fixture.withModel { model in
                #expect(model.settings.pasteShortcut == replacement)
                #expect(fixture.shortcuts.isRegistered(replacement))
                #expect(!fixture.shortcuts.isRegistered(.defaultPaste))
            }
        }
    }

    @Test
    func aStoredCaptureShortcutEqualToThePasteDefaultLeavesPasteUnset() async throws {
        // Versions before paste existed let the capture shortcut be ⌥⇧V (c839327).
        try await withFixture { fixture in
            let defaults = try #require(UserDefaults(suiteName: fixture.suite))
            UserDefaultsGlobalShortcutStore(defaults: defaults).save(.defaultPaste)
            try await fixture.withModel { model in
                #expect(model.settings.captureShortcut == .defaultPaste)
                #expect(model.settings.pasteShortcut == nil)
                #expect(model.settings.pasteShortcutFailure == .unset)
                #expect(fixture.shortcuts.isRegistered(.defaultPaste))

                let callbacks = model.managementCallbacks()
                callbacks.onPasteShortcutChange(.defaultPaste)
                #expect(model.settings.pasteShortcut == nil)
                #expect(model.settings.pasteShortcutFailure == .unset)
                callbacks.onPasteShortcutChange(GlobalShortcut(keyCode: 0, modifiers: []))
                #expect(model.settings.pasteShortcut == nil)
                #expect(model.settings.pasteShortcutFailure == .unset)

                let replacement = GlobalShortcut(keyCode: 9, modifiers: [.command, .option])
                callbacks.onPasteShortcutChange(replacement)
                #expect(model.settings.pasteShortcut == replacement)
                #expect(model.settings.pasteShortcutFailure == nil)
                #expect(fixture.shortcuts.isRegistered(replacement))
                #expect(model.settings.captureShortcut == .defaultPaste)
            }
        }
    }

    @Test
    func thePanelsPasteButtonClosesThePanelAndPastes() async throws {
        try await withResultFixture { fixture, model in
            var panelCloses = 0
            model.onCloseMenuPanel = { panelCloses += 1 }
            fixture.pasteboard.clearContents()
            let hosting = NSHostingView(rootView: model.menuView())
            hosting.frame = NSRect(x: 0, y: 0, width: MenuBarPanelMetrics.width, height: 420)
            let window = NSWindow(contentRect: hosting.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.contentView = hosting
            window.orderFront(nil)
            defer { window.orderOut(nil) }
            hosting.layoutSubtreeIfNeeded()

            try click(window, at: NSPoint(x: 225, y: hosting.bounds.maxY - 50 - MenuBarPanelMetrics.captureButtonHeight / 2))
            try await eventually { resultBoxPresentation()?.title == "Paste" }

            #expect(panelCloses == 1)
            #expect(resultBoxPresentation()?.body == .message("There's no text or image on the clipboard."))
            #expect(await fixture.capture.requests == 0)
        }
    }
}

// MARK: Helpers

/// What Copy Image in a WebKit view puts on the clipboard: the image as TIFF only, with its address as
/// plain text, as a URL and inside HTML and a web archive.
@MainActor
func putWebKitCopiedImage(_ tiff: Data, on pasteboard: NSPasteboard) {
    let address = "https://example.com/images/cat.png"
    let item = NSPasteboardItem()
    item.setData(tiff, forType: .tiff)
    item.setString(address, forType: NSPasteboard.PasteboardType("public.url"))
    item.setString("a cat", forType: NSPasteboard.PasteboardType("public.url-name"))
    item.setString(address, forType: .string)
    item.setData(Data("bplist00".utf8), forType: NSPasteboard.PasteboardType("com.apple.webarchive"))
    item.setString(#"<img src="\#(address)" alt="a cat">"#, forType: .html)
    pasteboard.clearContents()
    pasteboard.writeObjects([item])
}

/// One file copied in Finder, as seen on this Mac on 2026-11-18: a file reference, the file name as plain text
/// (UTF-8 and UTF-16) and the file's icon as `icns` data.
@MainActor
func putFinderCopiedFile(named name: String, on pasteboard: NSPasteboard) {
    let item = NSPasteboardItem()
    item.setString("file:///Users/someone/Documents/\(name)", forType: .fileURL)
    item.setString(name, forType: NSPasteboard.PasteboardType("public.utf16-external-plain-text"))
    item.setString(name, forType: .string)
    item.setData(Data(repeating: 0x69, count: 64), forType: NSPasteboard.PasteboardType("com.apple.icns"))
    pasteboard.clearContents()
    pasteboard.writeObjects([item])
}

/// The Pasted Text a DeepSeek text request sent as its user message.
func sentUserText(_ request: URLRequest) -> String? {
    guard let body = request.httpBody,
          let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
          let messages = json["messages"] as? [[String: Any]]
    else { return nil }
    return messages.first { $0["role"] as? String == "user" }?["content"] as? String
}

/// A TIFF with a transparent half, as a copied image arrives.
func pastedImage(width: Int, height: Int) throws -> Data {
    let context = try requireFixture(CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.setFillColor(red: 0.9, green: 0.3, blue: 0.1, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height / 2))
    let output = NSMutableData()
    let destination = try requireFixture(CGImageDestinationCreateWithData(output, UTType.tiff.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, try requireFixture(context.makeImage()), nil)
    CGImageDestinationFinalize(destination)
    return output as Data
}

/// The PNG an image request sent, from the data URL in its JSON body.
func sentPNG(_ request: URLRequest) -> Data? {
    func dataURL(in value: Any) -> String? {
        if let string = value as? String, string.hasPrefix("data:image/png;base64,") { return string }
        if let array = value as? [Any] { return array.lazy.compactMap(dataURL).first }
        if let object = value as? [String: Any] { return object.values.lazy.compactMap(dataURL).first }
        return nil
    }
    guard let body = request.httpBody,
          let json = try? JSONSerialization.jsonObject(with: body),
          let url = dataURL(in: json)
    else { return nil }
    return Data(base64Encoded: String(url.dropFirst("data:image/png;base64,".count)))
}

func pngSize(_ png: Data) throws -> (width: Int, height: Int) {
    let source = try requireFixture(CGImageSourceCreateWithData(png as CFData, nil))
    let image = try requireFixture(CGImageSourceCreateImageAtIndex(source, 0, nil))
    return (image.width, image.height)
}

@MainActor
func managedFiles(in fixture: ApplicationFixture) throws -> [URL] {
    let root = fixture.root.appendingPathComponent("Pictures")
    guard let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return [] }
    return files.compactMap { $0 as? URL }.filter { $0.pathExtension == "png" }
}

/// Presses a header button of the paste box once a box that just opened has drawn its content: a box shown
/// again after closing starts empty, and a press before SwiftUI renders the header lands on nothing.
@MainActor
func clickPasteBoxButton(_ box: NSWindow, fromEnd index: Int) async throws {
    for _ in 0..<3 {
        await Task.yield()
        pumpNativeEvents(box)
    }
    try clickResultBoxButton(box, fromEnd: index)
}

@MainActor
func pasteBoxOperations() -> CaptureResultBoxOperations? {
    (resultBox()?.contentView as? NSHostingView<CaptureResultBoxView>)?.rootView.operations
}

/// Lets main-actor work the paste started run before a test reads that it did nothing more.
@MainActor
func settleMainActor() async {
    for _ in 0..<10 { await Task.yield() }
    try? await Task.sleep(for: .milliseconds(100))
}
