import Foundation
import Testing
@testable import JustSnapCore

// Operations on Pasted Text (clipboard-paste::REQ-007).
extension PersistedOperationWorkspaceRunnerTests {
    @Test("a Pasted Text operation writes no file and sends the text with the record that holds it")
    func pastedTextIsSentWithItsRecordAndNoFile() async throws {
        let screenshots = RunnerScreenshotStoreProbe()
        let history = RunnerHistoryProbe()
        let provider = RunnerProviderProbe()
        let runner = makeRunner(screenshotStore: screenshots, history: history, provider: provider)
        let text = "  first line\n第二行 \n"

        let events = try await collect(await runner.run(
            input: .pastedText(text),
            operation: .translate(targetLanguage: "fr"),
            selection: ProviderSelection(providerID: "gemini", modelID: "vision")
        ))

        #expect(await screenshots.saveCount == 0)
        #expect(await provider.inputs == [.pastedText(text)])
        let prepared = try #require(await provider.preparedOperations.first)
        #expect(prepared.input == .pastedText(text))
        // The record the provider got is the one history saved, holding the same text.
        #expect(try await history.operation(id: prepared.operationID)?.input == .pastedText(text))
        #expect(await history.operations == [.translate(targetLanguage: "fr")])
        #expect(events.last == .succeeded(WorkspaceCommittedResult(
            sourceMarkdown: "Source", translationMarkdown: "Translation", segments: nil
        )))
    }

    @Test(
        "a Pasted Text request leaves the model's vision compatibility unchanged",
        arguments: [nil, ProviderAdapterError.imageInputUnsupported] as [ProviderAdapterError?]
    )
    func pastedTextDoesNotRecordVisionCompatibility(error: ProviderAdapterError?) async throws {
        let recorder = RunnerVisionRecorderProbe()
        let runner = makeRunner(
            provider: error.map { RunnerProviderProbe(error: $0) } ?? RunnerProviderProbe(),
            visionCompatibility: recorder
        )

        _ = try? await collect(await runner.run(
            input: .pastedText("words"),
            operation: .translate(targetLanguage: "fr"),
            selection: ProviderSelection(providerID: "gemini", modelID: "vision")
        ))

        #expect(await recorder.calls.isEmpty)
    }

    @Test("when the Pasted Text record cannot be saved nothing is sent, and Retry sends the same text")
    func unsavedPastedTextRecordIsRetriedWithTheSameText() async throws {
        let history = RunnerHistoryProbe(preparationError: RunnerProbeError.failed)
        let provider = RunnerProviderProbe()
        let runner = makeRunner(history: history, provider: provider)
        let text = " kept\nin memory "
        let session = OperationWorkspaceSession(input: .pastedText(text), runner: runner, activeGate: ActiveOperationGate())
        let selection = ProviderSelection(providerID: "gemini", modelID: "vision")
        await session.select(.translate)

        await #expect(throws: OperationWorkspaceRunFailure(code: "operation_failed")) {
            try await session.startSelectedOperation(selection: selection, targetLanguage: "en")
        }
        #expect(await session.snapshot().translate.attempt == .failed(code: "operation_failed"))
        #expect(await provider.streamCount == 0)

        await history.setPreparationError(nil)
        try await session.startSelectedOperation(selection: selection, targetLanguage: "en")

        #expect(await provider.inputs == [.pastedText(text)])
        let prepared = try #require(await provider.preparedOperations.first)
        #expect(try await history.operation(id: prepared.operationID)?.input == .pastedText(text))
    }

    @Test("rerunning a saved Pasted Text record sends its saved text and keeps the record")
    func rerunOfSavedPastedTextKeepsTheRecord() async throws {
        let history = RunnerHistoryProbe()
        let saved = try await history.prepareOperation(
            input: .pastedText("saved words"),
            selection: ProviderSelection(providerID: "gemini", modelID: "vision"),
            operation: .translate(targetLanguage: "fr")
        )
        let stored = try #require(try await history.operation(id: saved.operationID))
        let screenshots = RunnerScreenshotStoreProbe()
        let provider = RunnerProviderProbe()
        let runner = makeRunner(screenshotStore: screenshots, history: history, provider: provider, restoring: stored)

        _ = try await collect(await runner.run(
            input: .pastedText("saved words"),
            operation: .translate(targetLanguage: "fr"),
            selection: ProviderSelection(providerID: "openai", modelID: "vision")
        ))

        #expect(await provider.inputs == [.pastedText("saved words")])
        #expect(await provider.preparedOperations.map(\.operationID) == [stored.id])
        #expect(await history.operations == [.translate(targetLanguage: "fr")])
        #expect(await history.currentOutcomes[stored.id] == .succeeded(sourceMarkdown: "Source", translationMarkdown: "Translation"))
        #expect(await screenshots.saveCount == 0)
    }

    @Test("a rerun whose text differs from the saved record's is refused without a request")
    func rerunWithOtherTextIsRefused() async throws {
        let history = RunnerHistoryProbe()
        let saved = try await history.prepareOperation(
            input: .pastedText("saved words"),
            selection: ProviderSelection(providerID: "gemini", modelID: "vision"),
            operation: .translate(targetLanguage: "fr")
        )
        let stored = try #require(try await history.operation(id: saved.operationID))
        let provider = RunnerProviderProbe()
        let runner = makeRunner(history: history, provider: provider, restoring: stored)

        await #expect(throws: OperationWorkspaceRunFailure(code: "history_record_unavailable")) {
            _ = try await collect(await runner.run(
                input: .pastedText("other words"),
                operation: .translate(targetLanguage: "fr"),
                selection: ProviderSelection(providerID: "gemini", modelID: "vision")
            ))
        }

        #expect(await provider.streamCount == 0)
    }

    @Test("Text Extraction of Pasted Text is refused before any record or request")
    func extractionOfPastedTextIsRefused() async throws {
        let history = RunnerHistoryProbe()
        let provider = RunnerProviderProbe()
        let runner = makeRunner(history: history, provider: provider)

        await #expect(throws: OperationWorkspaceRunFailure(code: "operation_failed")) {
            _ = try await collect(await runner.run(
                input: .pastedText("words"),
                operation: .extractText,
                selection: ProviderSelection(providerID: "gemini", modelID: "vision")
            ))
        }

        #expect(await history.operations.isEmpty)
        #expect(await provider.streamCount == 0)
    }
}
