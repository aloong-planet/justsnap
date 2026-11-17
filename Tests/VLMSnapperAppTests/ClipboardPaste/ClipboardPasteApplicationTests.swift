import AppKit
import Foundation
import ImageIO
import SQLite3
import Testing
import UniformTypeIdentifiers
import VLMSnapperCore
import VLMSnapperUI
@testable import VLMSnapperApp

// clipboard-paste. The paste fixture's pasteboard is a private one the real reader reads; its layouts copy
// clipboards seen on this Mac on 2026-11-17 (WebKit's Copy Image). Not covered here, because they need the
// window server and other apps: what browsers other than WebKit and spreadsheets put on the clipboard,
// that showing the box leaves another app active, and the box's level above other apps' windows — checked
// on the installed build.
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
            let saved = try Data(contentsOf: URL(fileURLWithPath: record.operation.screenshot.path))
            let sent = try #require(await fixture.http.imageRequests.first.flatMap(sentPNG))
            #expect(sent == saved)
            let size = try pngSize(saved)
            #expect(size.width == 30 && size.height == 20)
        }
    }

    @Test
    func aTextClipboardIsReportedWithoutARequestOrRecord() async throws {
        try await withResultFixture { fixture, model in
            fixture.pasteboard.clearContents()
            fixture.pasteboard.setString("A paragraph of copied text", forType: .string)

            model.pasteFromClipboard()
            try await eventually { resultBoxPresentation()?.title == "Paste" }

            #expect(resultBoxPresentation()?.body == .message("The clipboard holds text. Only images can be pasted for now."))
            #expect(resultBoxPresentation()?.canRetry == false)
            await settleMainActor()
            #expect(await fixture.http.imageRequests.isEmpty)
            #expect(model.historyRecords.isEmpty)
            #expect(try managedFiles(in: fixture).isEmpty)
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

            try clickResultBoxButton(box, fromEnd: 0)

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

            try clickResultBoxButton(box, fromEnd: 0)
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

            try clickResultBoxButton(box, fromEnd: 0)
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
            let paths = Set(model.historyRecords.map(\.operation.screenshot.path))
            #expect(paths.count == 2)
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

/// Lets main-actor work the paste started run before a test reads that it did nothing more.
@MainActor
func settleMainActor() async {
    for _ in 0..<10 { await Task.yield() }
    try? await Task.sleep(for: .milliseconds(100))
}
