import AppKit
import UniformTypeIdentifiers
import VLMSnapperCore
import VLMSnapperUI

/// Reads what a paste may use from the clipboard, once per paste (clipboard-paste::REQ-003/AC-01, CON-001).
@MainActor
protocol ClipboardImageReading {
    func read() -> ClipboardSnapshot
}

/// Takes the first clipboard item that holds image data, in the item's own type order, the plain text,
/// and whether any item carries a file reference. File references are never followed.
struct PasteboardClipboardImageReader: ClipboardImageReading {
    let pasteboard: NSPasteboard

    func read() -> ClipboardSnapshot {
        let items = pasteboard.pasteboardItems ?? []
        if items.contains(where: { $0.types.contains(.fileURL) }) {
            return ClipboardSnapshot(images: [], plainText: nil, hasFileReference: true)
        }
        var images: [ClipboardImageRepresentation] = []
        for item in items {
            images = item.types.compactMap { type in
                guard let uniformType = UTType(type.rawValue),
                      // PDF is kept so a clipboard whose only image is vector content reads as unreadable.
                      uniformType.conforms(to: .image) || uniformType.conforms(to: .pdf),
                      let data = item.data(forType: type)
                else { return nil }
                return ClipboardImageRepresentation(typeIdentifier: type.rawValue, data: data)
            }
            if !images.isEmpty { break }
        }
        return ClipboardSnapshot(images: images, plainText: pasteboard.string(forType: .string))
    }
}

/// The paste result box and the one Pasted Image or Pasted Text it works on (clipboard-paste::REQ-005, REQ-006,
/// REQ-007, ADR-0019).
@MainActor
final class ClipboardPasteController {
    struct Environment {
        let reader: any ClipboardImageReading
        let makeSession: @MainActor (ProviderRequestInput) -> OperationWorkspaceSession
        /// Runs a request as a model request that belongs to no capture; `false` when it was not admitted.
        let performRequest: @MainActor (@MainActor () async -> Void) async -> Bool
        let selection: @MainActor () -> ProviderSelection?
        /// The failure shown when there is no selection to send to.
        let missingSelectionCode: @MainActor () -> String
        let providerSummary: @MainActor (ProviderSelection) -> String
        let providerName: @MainActor (ProviderSelection) -> String
        let targetLanguageCode: @MainActor () -> String
        let targetLanguages: @MainActor () -> [TargetLanguageOption]
        let changeTargetLanguage: @MainActor (String) -> Void
        let copyText: @MainActor (String) -> Void
        /// Diagnostics, history and model list after a request ends.
        let requestFinished: @MainActor (OperationWorkspaceSession, WorkspaceOperationKind) async -> Void
        let refreshHistory: @MainActor () async -> Void
    }

    private let environment: Environment
    private lazy var box = CaptureResultBoxPanelController(
        actions: CaptureResultBoxActions(
            onCopy: { [weak self] in self?.environment.copyText($0) },
            onRetry: { [weak self] in self?.retryShownResult() },
            onRetrySave: { [weak self] in Task { await self?.retrySavingShownResult() } },
            onClose: { [weak self] in self?.requestClose() }
        ),
        onEscape: { [weak self] in self?.requestClose() },
        style: .paste
    )
    private lazy var toolbarState = CaptureToolbarState(targetLanguageCode: environment.targetLanguageCode())

    private var session: OperationWorkspaceSession?
    private var sessionSource: CaptureResultBoxPresentation.InputSource = .paste
    private var snapshot = OperationWorkspaceSnapshot(
        selectedOperation: .extract,
        extract: WorkspaceOperationSlot(),
        translate: WorkspaceOperationSlot()
    )
    private var problem: CaptureResultBoxPresentation.PasteClipboardProblem?
    private var isPreparingImage = false
    private var preparationTask: Task<Void, Never>?
    private var shownOperation: WorkspaceOperationKind?
    private var runningOperation: WorkspaceOperationKind?
    private var runTask: Task<Void, Never>?
    private var hasUnsavedResult = false
    private var isConfirmingClose = false
    private var localFailures: [WorkspaceOperationKind: String] = [:]
    private var sessionProviderSummary: String?
    private var sessionProviderName = ""
    /// The language of the record in the translation slot; a rerun keeps it.
    private var sessionTargetLanguageCode: String?

    init(environment: Environment) {
        self.environment = environment
    }

    var isOpen: Bool { box.frame != nil }

    /// A running request, an image still being prepared, or an unsaved result: a new paste or capture
    /// does nothing (clipboard-paste::REQ-002/AC-04, REQ-005/AC-07).
    var holdsWork: Bool { runningOperation != nil || isPreparingImage || hasUnsavedResult }

    /// Reads the clipboard and shows what it gives in the box, on the display under the pointer unless the
    /// box is already open (clipboard-paste::REQ-005/AC-01, AC-05).
    func paste() {
        guard !holdsWork else { return }
        let clipboard = environment.reader.read()
        retireSession()
        toolbarState.targetLanguageCode = environment.targetLanguageCode()
        if clipboard.images.isEmpty {
            show(ClipboardPaste.resolve(clipboard))
            return
        }
        // Decoding a large image happens away from the interface; meanwhile the request is being prepared.
        isPreparingImage = true
        shownOperation = .extract
        showBox()
        preparationTask = Task { [weak self] in
            let content = await Task.detached(priority: .userInitiated) {
                ClipboardPaste.resolve(clipboard)
            }.value
            guard let self, !Task.isCancelled else { return }
            isPreparingImage = false
            preparationTask = nil
            show(content)
        }
    }

    /// A capture's freeze frame is on screen: the idle box gives way to it (clipboard-paste::REQ-005/AC-06).
    func closeForCapture() async {
        guard isOpen, !holdsWork else { return }
        _ = await close()
    }

    /// Cancels a running request and confirms an unsaved result before quitting. Returns `false` if the
    /// user keeps the result (clipboard-paste::REQ-005/AC-08).
    func prepareForTermination() async -> Bool {
        guard isOpen || session != nil else { return true }
        return await close()
    }

    private func show(_ content: ClipboardPasteContent) {
        switch content {
        case let .image(png):
            start(.png(png), source: .paste)
        case let .text(text):
            start(.pastedText(text), source: .pastedText)
        case .file:
            showProblem(.file)
        case .empty:
            showProblem(.empty)
        case .unreadable:
            showProblem(.unreadable)
        }
    }

    /// A Pasted Image starts Text Extraction at once; Pasted Text starts Screenshot Translation into the
    /// remembered target language (clipboard-paste::REQ-006/AC-01).
    private func start(_ input: ProviderRequestInput, source: CaptureResultBoxPresentation.InputSource) {
        problem = nil
        session = environment.makeSession(input)
        sessionSource = source
        showBox()
        let operation: WorkspaceOperationKind = source == .pastedText ? .translate : .extract
        startRequest(operation, targetLanguage: environment.targetLanguageCode())
    }

    private func showProblem(_ value: CaptureResultBoxPresentation.PasteClipboardProblem) {
        problem = value
        shownOperation = nil
        showBox()
    }

    private func showBox() {
        refresh()
        guard !isOpen else { return }
        box.state.operations = CaptureResultBoxOperations(
            toolbarState: toolbarState,
            targetLanguages: environment.targetLanguages(),
            onStart: { [weak self] in self?.handleOperationPress($0) },
            onTargetLanguageChange: { [weak self] in self?.changeTargetLanguage($0) }
        )
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(pointer, $0.frame, false) })
            ?? NSScreen.main
        else { return }
        box.show(on: screen)
    }

    /// The previous paste's session is idle by now; its records stay as they are.
    private func retireSession() {
        if let session { Task { _ = await session.close() } }
        session = nil
        snapshot = OperationWorkspaceSnapshot(
            selectedOperation: .extract,
            extract: WorkspaceOperationSlot(),
            translate: WorkspaceOperationSlot()
        )
        problem = nil
        shownOperation = nil
        hasUnsavedResult = false
        localFailures = [:]
        sessionProviderSummary = nil
        sessionProviderName = ""
        sessionTargetLanguageCode = nil
    }

    // MARK: Operations

    private func handleOperationPress(_ operation: WorkspaceOperationKind) {
        guard runningOperation == nil, session != nil else { return }
        guard wouldStartRequest(operation) else {
            shownOperation = operation
            refresh()
            return
        }
        guard !hasUnsavedResult else { return }
        startRequest(operation, targetLanguage: environment.targetLanguageCode())
    }

    private func slot(_ operation: WorkspaceOperationKind) -> WorkspaceOperationSlot {
        if let code = localFailures[operation] {
            return WorkspaceOperationSlot(attempt: .failed(code: code))
        }
        if isPreparingImage { return WorkspaceOperationSlot(attempt: .preparing) }
        return operation == .extract ? snapshot.extract : snapshot.translate
    }

    private func wouldStartRequest(_ operation: WorkspaceOperationKind) -> Bool {
        if slot(operation).attempt == .neverStarted { return true }
        return operation == .translate && sessionTargetLanguageCode != environment.targetLanguageCode()
    }

    private func startRequest(_ operation: WorkspaceOperationKind, targetLanguage: String) {
        guard let session else { return }
        shownOperation = operation
        guard let selection = environment.selection() else {
            localFailures[operation] = environment.missingSelectionCode()
            refresh()
            return
        }
        localFailures[operation] = nil
        if operation == .translate { sessionTargetLanguageCode = targetLanguage }
        sessionProviderSummary = environment.providerSummary(selection)
        sessionProviderName = environment.providerName(selection)
        runningOperation = operation
        refresh()
        runTask = Task { [weak self] in
            guard let self else { return }
            let accepted = await environment.performRequest {
                await self.run(operation, in: session, selection: selection, targetLanguage: targetLanguage)
            }
            await sync(session)
            await environment.requestFinished(session, operation)
            guard self.session === session else { return }
            if !accepted { localFailures[operation] = "operation_failed" }
            runningOperation = nil
            runTask = nil
            refresh()
        }
    }

    private func run(
        _ operation: WorkspaceOperationKind,
        in session: OperationWorkspaceSession,
        selection: ProviderSelection,
        targetLanguage: String
    ) async {
        await session.select(operation)
        let observation = Task { [weak self] in
            while !Task.isCancelled {
                await self?.sync(session)
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
        defer { observation.cancel() }
        do {
            try await session.startSelectedOperation(selection: selection, targetLanguage: targetLanguage)
        } catch OperationWorkspaceSessionError.busy, OperationWorkspaceSessionError.unsavedResultRequiresSave {
            localFailures[operation] = "operation_failed"
        } catch {
            // The session recorded the failure or cancellation in the operation's slot.
        }
        await sync(session)
    }

    private func sync(_ session: OperationWorkspaceSession) async {
        let latest = await session.snapshot()
        let unsaved = await session.hasUnsavedResult
        guard self.session === session else { return }
        snapshot = latest
        hasUnsavedResult = unsaved
        refresh()
    }

    private func retryShownResult() {
        guard runningOperation == nil, !hasUnsavedResult, session != nil, let operation = shownOperation else { return }
        startRequest(operation, targetLanguage: sessionTargetLanguageCode ?? environment.targetLanguageCode())
    }

    private func retrySavingShownResult() async {
        guard let session, let operation = shownOperation else { return }
        await session.select(operation)
        try? await session.retrySavingSelectedResult()
        await sync(session)
        await environment.refreshHistory()
    }

    private func changeTargetLanguage(_ code: String) {
        environment.changeTargetLanguage(code)
        targetLanguageDidChange()
    }

    /// The remembered target language changed here or elsewhere; the shown result stays as it is
    /// (v1-core::REQ-017/AC-03).
    func targetLanguageDidChange() {
        toolbarState.targetLanguageCode = environment.targetLanguageCode()
        refresh()
    }

    // MARK: Closing

    private func requestClose() {
        Task { _ = await close() }
    }

    /// Closing during a request cancels it; an unsaved result asks first, in a sheet on the box
    /// (clipboard-paste::REQ-005/AC-03, AC-04). Returns `false` if the user keeps the box.
    private func close() async -> Bool {
        guard !isConfirmingClose else { return false }
        preparationTask?.cancel()
        preparationTask = nil
        isPreparingImage = false
        if let session {
            // A request task that has not reached the session yet must not start after this.
            let request = runTask
            request?.cancel()
            if await session.close() == .confirmDiscardUnsavedResult {
                isConfirmingClose = true
                let response = await box.presentSheet(UnsavedResultConfirmation.makeAlert())
                isConfirmingClose = false
                guard response == .alertFirstButtonReturn else { return false }
                await session.discardUnsavedResults()
            }
            await request?.value
        }
        retireSession()
        runningOperation = nil
        box.reset()
        return true
    }

    // MARK: Presentation

    private func refresh() {
        toolbarState.currentOperation = shownOperation
        toolbarState.isRequestRunning = runningOperation != nil || isPreparingImage
        toolbarState.unavailableOperations = hasUnsavedResult
            ? Set(WorkspaceOperationKind.allCases.filter(wouldStartRequest))
            : []
        let presentation: CaptureResultBoxPresentation?
        if let problem {
            presentation = .pasteProblem(problem)
        } else if let operation = shownOperation {
            presentation = CaptureResultBoxPresentation(
                operation: operation,
                targetLanguageName: VLMSnapperLocalization.localizedLanguageName(
                    for: sessionTargetLanguageCode ?? environment.targetLanguageCode()
                ),
                providerSummary: sessionProviderSummary
                    ?? environment.selection().map(environment.providerSummary) ?? "",
                slot: slot(operation),
                // Until a finished request has wrapped up, Retry would do nothing.
                retryAvailable: !hasUnsavedResult && runningOperation == nil,
                source: sessionSource,
                providerName: sessionProviderName
            )
        } else {
            presentation = nil
        }
        if box.state.presentation != presentation {
            box.state.presentation = presentation
        }
    }
}
