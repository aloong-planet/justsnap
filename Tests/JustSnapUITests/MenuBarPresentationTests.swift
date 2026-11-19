import AppKit
import Foundation
import Testing
import JustSnapCore
@testable import JustSnapUI

@Suite("Ticket 13 menu bar presentation", .serialized)
struct MenuBarPresentationTests {
    @Test("recent records map to real operation, time, status, and screenshot data")
    func recordPresentation() {
        LocalizationTestCoordinator.acquire()
        defer { LocalizationTestCoordinator.release() }
        JustSnapLocalization.configure(effectiveLanguage: .english)
        defer {
            JustSnapLocalization.configure(effectiveLanguage: .simplifiedChinese)
        }
        let now = Date(timeIntervalSince1970: 10_000)
        let succeeded = record(
            status: .succeeded,
            kind: .translate,
            createdAt: now.addingTimeInterval(-120),
            source: "# Designing Calm Software\nSecond line"
        )
        let failed = record(
            status: .failed,
            kind: .extract,
            createdAt: now.addingTimeInterval(-3_600),
            source: nil
        )

        let succeededItem = MenuRecentItem(record: succeeded, now: now)
        #expect(succeededItem.title == "Designing Calm Software")
        #expect(succeededItem.detail == "Translate · 2 min ago")
        #expect(succeededItem.status == .succeeded)
        #expect(succeededItem.screenshotURL?.path == "/tmp/capture.png")

        let failedItem = MenuRecentItem(record: failed, now: now)
        #expect(failedItem.title == "Provider request failed")
        #expect(failedItem.detail == "Extract Text · 1 hr ago")
        #expect(failedItem.status == .failed)
    }

    @Test("a Pasted Text record's recent item has no screenshot and keeps its title and detail")
    func pastedTextRecordPresentation() {
        LocalizationTestCoordinator.acquire()
        defer { LocalizationTestCoordinator.release() }
        JustSnapLocalization.configure(effectiveLanguage: .english)
        defer {
            JustSnapLocalization.configure(effectiveLanguage: .simplifiedChinese)
        }
        let now = Date(timeIntervalSince1970: 10_000)
        let pasted = HistoryRecord(
            operation: StoredOperation(
                id: UUID(),
                input: .pastedText("Quarterly notes\nmore"),
                selection: ProviderSelection(providerID: "deepseek", modelID: "vision-model"),
                status: .succeeded,
                sourceMarkdown: "## Quarterly notes"
            ),
            createdAt: now.addingTimeInterval(-120),
            isPinned: false
        )

        let item = MenuRecentItem(record: pasted, now: now)

        #expect(item.screenshotURL == nil)
        #expect(item.title == "Quarterly notes")
        #expect(item.detail == "Extract Text · 2 min ago")
    }

    @Test("a recent row shows its screenshot, the text symbol for a Pasted Text record, or the capture symbol when the screenshot is missing")
    func recentThumbnail() {
        let image = NSImage(size: NSSize(width: 1, height: 1))
        let captured = MenuRecentItem(id: "1", title: "t", detail: "d", screenshotURL: URL(fileURLWithPath: "/tmp/capture.png"))
        let pasted = MenuRecentItem(id: "2", title: "t", detail: "d", screenshotURL: nil)

        guard case let .image(shown) = captured.thumbnail(loading: { _ in image }) else {
            Issue.record("A loadable screenshot should be shown")
            return
        }
        #expect(shown === image)
        guard case .missingScreenshot = captured.thumbnail(loading: { _ in nil }) else {
            Issue.record("An unloadable screenshot should show the capture symbol")
            return
        }
        guard case .pastedText = pasted.thumbnail(loading: { _ in image }) else {
            Issue.record("A record without a screenshot should show the text symbol")
            return
        }
    }

    @Test("provider badge never claims availability before a selected model exists")
    func providerBadgePresentation() {
        #expect(MenuProviderPresentation(readiness: .missing).isAvailable == false)
        #expect(
            MenuProviderPresentation(readiness: .pendingModel(.gemini)).isAvailable == false
        )
        let ready = MenuProviderPresentation(
            readiness: .ready(provider: .deepSeek, modelID: "vision-model")
        )
        #expect(ready.isAvailable)
        #expect(ready.providerName == "DeepSeek")
    }

    @Test("confirmed menu panel geometry remains independent from toolbar geometry")
    func confirmedGeometry() {
        #expect(MenuBarPanelMetrics.width == 300)
        #expect(MenuBarPanelMetrics.arrowSize == CGSize(width: 8, height: 4))
        #expect(MenuBarPanelMetrics.outerCornerRadius == 13)
        #expect(MenuBarPanelMetrics.captureButtonHeight == 36)
        #expect(MenuBarPanelMetrics.recentThumbnailSize == CGSize(width: 58, height: 42))
    }

    private func record(
        status: OperationStatus,
        kind: PersistedOperationKind,
        createdAt: Date,
        source: String?
    ) -> HistoryRecord {
        HistoryRecord(
            operation: StoredOperation(
                id: UUID(),
                screenshot: ManagedScreenshot(path: "/tmp/capture.png", sha256: "sha"),
                selection: ProviderSelection(providerID: "deepseek", modelID: "vision-model"),
                status: status,
                sourceMarkdown: source,
                normalizedErrorCode: status == .failed ? "provider_unavailable" : nil,
                kind: kind,
                targetLanguage: kind == .translate ? "zh-Hans" : nil
            ),
            createdAt: createdAt,
            isPinned: false
        )
    }
}
