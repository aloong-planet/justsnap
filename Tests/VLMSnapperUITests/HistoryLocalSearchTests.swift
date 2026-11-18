import Foundation
import Testing
import VLMSnapperCore
@testable import VLMSnapperUI

@Suite("History local search")
struct HistoryLocalSearchTests {
    @Test(
        "the history list's search matches results and Pasted Text, ignoring case and surrounding spaces",
        arguments: [
            ("  revenue ", OperationInput.pastedText("Quarterly REVENUE notes"), nil, true),
            ("revenue", .image(ManagedScreenshot(path: "/Pictures/a.png", sha256: "a")), nil, false),
            ("季度", .image(ManagedScreenshot(path: "/Pictures/a.png", sha256: "a")), "季度收入", true),
            ("", .pastedText("anything"), nil, true),
            ("missing", .pastedText("Quarterly revenue"), "收入", false),
        ] as [(String, OperationInput, String?, Bool)]
    )
    func searchMatchesResultsAndPastedText(query: String, input: OperationInput, source: String?, matches: Bool) {
        let record = HistoryRecord(
            operation: StoredOperation(
                id: UUID(),
                input: input,
                selection: ProviderSelection(providerID: "openai", modelID: "vision"),
                status: .succeeded,
                sourceMarkdown: source
            ),
            createdAt: Date(timeIntervalSince1970: 0),
            isPinned: false
        )

        #expect(HistoryLocalSearch.matches(record, query: query) == matches)
    }

    @Test(
        "history detail offers Retry for a Pasted Text record without an image, and for an image record once it is loaded",
        arguments: [
            (OperationInput.pastedText("words"), OperationStatus.succeeded, false, true),
            (.image(ManagedScreenshot(path: "/Pictures/a.png", sha256: "a")), .succeeded, false, false),
            (.image(ManagedScreenshot(path: "/Pictures/a.png", sha256: "a")), .failed, true, true),
            (.pastedText("words"), .streaming, false, false),
        ] as [(OperationInput, OperationStatus, Bool, Bool)]
    )
    func retryAvailability(input: OperationInput, status: OperationStatus, hasLoadedImage: Bool, available: Bool) {
        let record = HistoryRecord(
            operation: StoredOperation(
                id: UUID(),
                input: input,
                selection: ProviderSelection(providerID: "openai", modelID: "vision"),
                status: status
            ),
            createdAt: Date(timeIntervalSince1970: 0),
            isPinned: false
        )

        #expect(HistoryRetryAvailability.isAvailable(
            for: record, allowsStart: true, isRunning: false, hasLoadedImage: hasLoadedImage
        ) == available)
    }
}
