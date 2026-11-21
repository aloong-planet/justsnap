import AppKit
import SwiftUI
import JustSnapCore
import JustSnapUI

/// The seven scenes. Each puts real views of the app (the capture toolbar, the result box, the menu bar panel,
/// the management window's history and provider pages) over an invented screen, with fixture content only.
enum ShotScene: String, CaseIterable {
    case hero, select, extract, translate, paste, history, providers

    @MainActor
    func view(_ locale: ShotLocale) -> AnyView {
        switch self {
        case .hero: AnyView(HeroScene(locale: locale))
        case .select: AnyView(SelectScene(locale: locale))
        case .extract: AnyView(ExtractScene(locale: locale))
        case .translate: AnyView(TranslateScene(locale: locale))
        case .paste: AnyView(PasteScene(locale: locale))
        case .history: AnyView(HistoryScene(locale: locale))
        case .providers: AnyView(ProvidersScene(locale: locale))
        }
    }
}

// MARK: - Shared pieces

private let modelSummary = "OpenAI · gpt-4o"

/// The moment the history's relative and absolute times are counted from: 2026-09-21 10:30 UTC
let fixtureNow = Date(timeIntervalSince1970: 1_789_986_600)

@MainActor
private func targetLanguages() -> [TargetLanguageOption] {
    ["zh-Hans", "en", "ja", "ko", "fr", "de", "es"].map {
        TargetLanguageOption(code: $0, name: JustSnapLocalization.localizedLanguageName(for: $0))
    }
}

/// The capture toolbar of the freeze overlay, the app's own view, in the state of an operation.
@MainActor
private func captureToolbar(_ locale: ShotLocale, current: WorkspaceOperationKind?) -> some View {
    let state = CaptureToolbarState(targetLanguageCode: locale.targetLanguageCode)
    state.currentOperation = current
    return CaptureOperationToolbar(
        state: state,
        targetLanguages: targetLanguages(),
        onStart: { _ in },
        onTargetLanguageChange: { _ in },
        onCopy: {},
        onSave: {},
        onCancel: {}
    )
}

/// The result box of the app at the place a capture puts it: the display's right edge, inset 12pt.
@MainActor
private func resultBox(
    _ presentation: CaptureResultBoxPresentation,
    locale: ShotLocale,
    toolbarState: CaptureToolbarState? = nil
) -> some View {
    let state = CaptureResultBoxState()
    state.presentation = presentation
    if let toolbarState {
        state.operations = CaptureResultBoxOperations(
            toolbarState: toolbarState,
            targetLanguages: targetLanguages(),
            onStart: { _ in },
            onTargetLanguageChange: { _ in }
        )
    }
    return CaptureResultBoxView(
        state: state,
        actions: CaptureResultBoxActions(onCopy: { _ in }, onRetry: {}, onRetrySave: {}, onClose: {})
    )
    .shadow(color: .black.opacity(0.28), radius: 14, y: 6)
}

private func translationSegments(_ copy: ShotCopy) -> [TranslationSegment] {
    var segments = [TranslationSegment(
        id: "s0", block: "b0", kind: .heading,
        source: copy.translateHeading.source, translation: copy.translateHeading.translation
    )]
    for (index, paragraph) in copy.translateParagraphs.enumerated() {
        segments.append(TranslationSegment(
            id: "s\(index + 1)", block: "b\(index + 1)", kind: .paragraph,
            source: paragraph.source, translation: paragraph.translation
        ))
    }
    return segments
}

// MARK: - Select and hero

/// The region selection: the screen frozen, one region chosen and the capture toolbar under it.
private struct SelectScene: View {
    let locale: ShotLocale

    var body: some View {
        let copy = locale.copy
        let selection = CGRect(x: 58, y: 88, width: 524, height: 278)
        ZStack(alignment: .topLeading) {
            Wallpaper()
            FauxWindow(title: copy.sideWindowTitle, size: CGSize(width: 290, height: 340)) {
                FauxLines(lines: copy.sideLines).padding(18)
            }
            .offset(x: 640, y: 124)
            FauxWindow(title: copy.readerWindowTitle, size: CGSize(width: 630, height: 466)) {
                VStack(alignment: .leading, spacing: 14) {
                    FauxArticle(heading: copy.articleTitle, paragraphs: copy.articleParagraphs)
                    FauxChart(height: 64)
                }
                .frame(width: 490, alignment: .leading)
                .padding(.leading, 40)
                .padding(.top, 40)
            }
            .offset(x: 40, y: 40)
            FreezeOverlay(selection: selection, showsHandles: true)
            captureToolbar(locale, current: nil)
                .offset(x: selection.minX, y: selection.maxY + 4)
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
    }
}

/// The hero: the moment a region is being dragged out, over a busy screen of another kind.
private struct HeroScene: View {
    let locale: ShotLocale

    var body: some View {
        let copy = locale.copy
        let selection = CGRect(x: 186, y: 222, width: 722, height: 198)
        ZStack(alignment: .topLeading) {
            Wallpaper()
            FauxWindow(title: copy.dashboardWindowTitle, size: CGSize(width: 895, height: 487)) {
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(copy.dashboardSidebar.enumerated()), id: \.offset) { index, item in
                            Text(item)
                                .font(.system(size: 13, weight: index == 1 ? .semibold : .regular))
                                .foregroundStyle(index == 1 ? Ink.accent : Ink.text)
                        }
                    }
                    .padding(.top, 22)
                    .padding(.leading, 20)
                    .frame(width: 150, alignment: .topLeading)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
                    .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(copy.dashboardCardTitle)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Ink.text)
                            FauxChart(values: [0.3, 0.45, 0.4, 0.62, 0.55, 0.8, 0.7], height: 74)
                        }
                        .padding(14)
                        .background(Color(red: 0.97, green: 0.97, blue: 0.98), in: RoundedRectangle(cornerRadius: 8))
                        FauxTable(header: copy.dashboardTableHeader, rows: copy.dashboardRows)
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .offset(x: 28, y: 24)
            FreezeOverlay(selection: selection)
            CrosshairCursor()
                .offset(x: selection.maxX - 9.5, y: selection.maxY - 9.5)
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
    }
}

private struct FauxTable: View {
    let header: [String]
    let rows: [[String]]

    var body: some View {
        VStack(spacing: 0) {
            row(header, weight: .semibold, color: Ink.secondary)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, cells in
                Divider()
                row(cells, weight: .regular, color: Ink.text)
            }
        }
    }

    private func row(_ cells: [String], weight: Font.Weight, color: Color) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                Text(cell)
                    .font(.system(size: 13, weight: weight))
                    .foregroundStyle(color)
                    .frame(width: index == 0 ? 280 : 150, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 9)
    }
}

// MARK: - Extract and translate

/// Extract: the selection, the toolbar with Extract current, and the result box with the Markdown arriving.
private struct ExtractScene: View {
    let locale: ShotLocale

    /// The text as far as it has arrived: the end cut off, back to a whole word where words are spaced.
    static func unfinished(_ text: String, dropping count: Int) -> String {
        var received = String(text.dropLast(count))
        if let space = received.lastIndex(of: " "), received.distance(from: space, to: received.endIndex) < 14 {
            received = String(received[..<space])
        }
        return received
    }

    var body: some View {
        let copy = locale.copy
        let document = copy.extractDocument
        let top: CGFloat = 66
        let selection = CGRect(x: 40, y: top + 36, width: 452, height: 322)
        // Streaming: the closing line is half there, as in a request that has not finished.
        let received = Self.unfinished(document.markdown, dropping: (document.closing.last?.count ?? 0) / 2)
        let presentation = CaptureResultBoxPresentation(
            operation: .extract,
            targetLanguageName: "",
            providerSummary: modelSummary,
            slot: WorkspaceOperationSlot(attempt: .streaming, sourceDelta: received)
        )
        ZStack(alignment: .topLeading) {
            Wallpaper()
            FauxWindow(title: copy.extractWindowTitle, size: CGSize(width: 480, height: 398)) {
                FauxArticle(
                    heading: document.heading,
                    paragraphs: document.paragraphs,
                    bullets: document.bullets,
                    closing: document.closing,
                    headingSize: 20
                )
                .frame(width: 400, alignment: .leading)
                .padding(.leading, 30)
                .padding(.top, 26)
            }
            .offset(x: 24, y: top)
            FreezeOverlay(selection: selection, showsHandles: true)
            captureToolbar(locale, current: .extract)
                .offset(x: selection.minX, y: selection.maxY + 4)
            resultBox(presentation, locale: locale)
                .frame(width: CaptureResultBoxMetrics.width, height: canvasSize.height - 24)
                .offset(x: canvasSize.width - 12 - CaptureResultBoxMetrics.width, y: 12)
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
    }
}

/// Translate: a page in another language selected, the translation in the result box beside it.
private struct TranslateScene: View {
    let locale: ShotLocale

    var body: some View {
        let copy = locale.copy
        let top: CGFloat = 104
        let selection = CGRect(x: 40, y: top + 36, width: 452, height: 252)
        let toolbarState = CaptureToolbarState(targetLanguageCode: locale.targetLanguageCode)
        let translation = ([copy.translateHeading] + copy.translateParagraphs).map(\.translation).joined(separator: "\n\n")
        let presentation = CaptureResultBoxPresentation(
            operation: .translate,
            targetLanguageName: JustSnapLocalization.localizedLanguageName(for: locale.targetLanguageCode),
            targetLanguageCode: locale.targetLanguageCode,
            providerSummary: modelSummary,
            slot: WorkspaceOperationSlot(
                attempt: .succeeded,
                committedResult: WorkspaceCommittedResult(
                    sourceMarkdown: ([copy.translateHeading] + copy.translateParagraphs).map(\.source).joined(separator: "\n\n"),
                    translationMarkdown: translation,
                    segments: translationSegments(copy)
                )
            )
        )
        ZStack(alignment: .topLeading) {
            Wallpaper()
            FauxWindow(title: copy.translateWindowTitle, size: CGSize(width: 480, height: 328)) {
                FauxArticle(
                    heading: copy.translateHeading.source,
                    paragraphs: copy.translateParagraphs.map(\.source),
                    headingSize: 20
                )
                .frame(width: 400, alignment: .leading)
                .padding(.leading, 30)
                .padding(.top, 26)
            }
            .offset(x: 24, y: top)
            FreezeOverlay(selection: selection, showsHandles: true)
            captureToolbar(locale, current: .translate)
                .offset(x: selection.minX, y: selection.maxY + 4)
            resultBox(presentation, locale: locale, toolbarState: toolbarState)
                .frame(width: CaptureResultBoxMetrics.width, height: canvasSize.height - 24)
                .offset(x: canvasSize.width - 12 - CaptureResultBoxMetrics.width, y: 12)
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
    }
}

// MARK: - Paste

/// Paste: the menu bar panel with its Paste button, and the floating result box the clipboard text opens.
private struct PasteScene: View {
    let locale: ShotLocale

    var body: some View {
        let copy = locale.copy
        let toolbarState = CaptureToolbarState(targetLanguageCode: locale.targetLanguageCode)
        let presentation = CaptureResultBoxPresentation(
            operation: .translate,
            targetLanguageName: JustSnapLocalization.localizedLanguageName(for: locale.targetLanguageCode),
            targetLanguageCode: locale.targetLanguageCode,
            providerSummary: modelSummary,
            slot: WorkspaceOperationSlot(
                attempt: .succeeded,
                committedResult: WorkspaceCommittedResult(
                    sourceMarkdown: copy.pasteSource.joined(separator: "\n\n"),
                    translationMarkdown: copy.pasteTranslation.joined(separator: "\n\n"),
                    segments: zip(copy.pasteSource, copy.pasteTranslation).enumerated().map { index, pair in
                        TranslationSegment(id: "p\(index)", block: "pb\(index)", kind: .paragraph, source: pair.0, translation: pair.1)
                    }
                )
            ),
            source: .pastedText
        )
        let recent = copy.pasteRecent.enumerated().map { index, item in
            MenuRecentItem(id: "\(index)", title: item.title, detail: item.detail, screenshotURL: nil)
        }
        ZStack(alignment: .topLeading) {
            Wallpaper()
            FauxMenuBar(statusItemX: 190)
            MenuBarPanelView(
                recentItems: recent,
                provider: .ready(provider: .openAI, modelID: "gpt-4o"),
                targetLanguageCode: locale.targetLanguageCode,
                targetLanguages: targetLanguages(),
                onCapture: {},
                onOpenRecent: { _ in },
                onNavigate: { _ in },
                onCheckUpdates: {}
            )
            .frame(width: 300)
            .fixedSize(horizontal: false, vertical: true)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.black.opacity(0.14), lineWidth: 0.5) }
            .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
            .offset(x: 40, y: 32)
            resultBox(presentation, locale: locale, toolbarState: toolbarState)
                .frame(width: CaptureResultBoxMetrics.width, height: canvasSize.height - 24)
                .offset(x: canvasSize.width - 12 - CaptureResultBoxMetrics.width, y: 12)
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
    }
}

// MARK: - History and providers

/// A management window cut at the bottom edge of the shot: the app's own `ManagementCenterView` under an invented
/// title bar. Its list ends inside the frame, so the cut never runs through a row.
private struct ManagementWindowShot<Content: View>: View {
    let title: String
    let titleBarHeight: CGFloat
    let windowHeight: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color(red: 0.93, green: 0.93, blue: 0.94)
                HStack(spacing: 8) {
                    ForEach([Color(red: 1, green: 0.37, blue: 0.34), Color(red: 1, green: 0.74, blue: 0.18), Color(red: 0.16, green: 0.78, blue: 0.25)], id: \.self) {
                        Circle().fill($0).frame(width: 12, height: 12)
                    }
                    Spacer()
                }
                .padding(.leading, 14)
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Ink.secondary)
            }
            .frame(height: titleBarHeight)
            Divider()
            content()
                .frame(width: canvasSize.width, height: windowHeight)
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
        .clipped()
        .background(Color.white)
    }
}

@MainActor
private func historyRecords(_ copy: ShotCopy, now: Date) -> [HistoryRecord] {
    copy.historyRows.enumerated().map { index, row in
        let id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!
        let isFirst = index == 0
        let source = isFirst
            ? ([copy.translateHeading] + copy.translateParagraphs).map(\.source).joined(separator: "\n\n")
            : (row.snippet.isEmpty ? row.source : "\(row.source)\n\n\(row.snippet)")
        let translation = isFirst
            ? ([copy.translateHeading] + copy.translateParagraphs).map(\.translation).joined(separator: "\n\n")
            : row.translation
        let status: OperationStatus = switch row.status {
        case .succeeded: .succeeded
        case .failed: .failed
        case .canceled: .canceled
        }
        let operation = StoredOperation(
            id: id,
            screenshot: ManagedScreenshot(path: "/fixture/\(id).png", sha256: "fixture"),
            selection: ProviderSelection(providerID: "OpenAI", modelID: "gpt-4o"),
            status: status,
            sourceMarkdown: status == .succeeded || status == .canceled ? source : nil,
            translationMarkdown: status == .succeeded ? translation : nil,
            normalizedErrorCode: status == .failed ? "provider.unavailable" : nil,
            kind: row.kind == .translate ? .translate : .extract,
            targetLanguage: row.kind == .translate ? "zh-Hans" : nil,
            segments: isFirst ? translationSegments(copy) : nil
        )
        return HistoryRecord(
            operation: operation,
            createdAt: now.addingTimeInterval(-Double(row.minutesAgo) * 60),
            isPinned: row.pinned,
            metrics: PersistedOperationMetrics(
                firstTextLatencyMilliseconds: 430,
                totalLatencyMilliseconds: 1_280,
                usage: ProviderTokenUsage(inputTokens: 612, outputTokens: 148, totalTokens: 760)
            )
        )
    }
}

/// The page of the original image: an invented screen capture the history keeps, as wide as the preview is.
@MainActor
private func originalImage(_ locale: ShotLocale) -> NSImage? {
    let copy = locale.copy
    let page = FauxArticle(
        heading: copy.translateHeading.source,
        paragraphs: [copy.translateParagraphs[0].source],
        headingSize: 18,
        bodySize: 13
    )
    .padding(22)
    .frame(width: 600, height: 120, alignment: .topLeading)
    .background(Color.white)
    let renderer = ImageRenderer(content: page)
    renderer.scale = 2
    return renderer.nsImage
}

private struct HistoryScene: View {
    let locale: ShotLocale
    static let titleBarHeight: CGFloat = 26
    static let windowHeight: CGFloat = 640

    var body: some View {
        let copy = locale.copy
        let now = fixtureNow
        let records = historyRecords(copy, now: now)
        ManagementWindowShot(
            title: JustSnapLocalization.localizedString(forKey: "app.name"),
            titleBarHeight: Self.titleBarHeight,
            windowHeight: Self.windowHeight
        ) {
            ManagementCenterView(
                destination: .history,
                records: records,
                selectedRecordID: records.first?.id,
                selectedImage: originalImage(locale)
            )
        }
    }
}

private struct ProvidersScene: View {
    let locale: ShotLocale
    static let titleBarHeight: CGFloat = 26
    static let windowHeight: CGFloat = 640

    var body: some View {
        let editor = ProviderCredentialEditor(loadedValue: "demo-key-not-a-real-secret")
        let configurations: [ProviderID: ProviderConfiguration] = [
            .deepSeek: ProviderConfiguration(
                models: [ProviderModelState(id: "deepseek-v4-flash-vision-exp", visionCompatibility: .verified)],
                fetchedAt: fixtureNow,
                selectedModelID: "deepseek-v4-flash-vision-exp"
            ),
            .openAI: ProviderConfiguration(
                models: [ProviderModelState(id: "gpt-4o", visionCompatibility: .verified)],
                fetchedAt: fixtureNow,
                selectedModelID: "gpt-4o"
            ),
            .gemini: ProviderConfiguration(
                models: [ProviderModelState(id: "gemini-2.5-flash", visionCompatibility: .verified)],
                fetchedAt: fixtureNow,
                selectedModelID: "gemini-2.5-flash"
            ),
        ]
        ManagementWindowShot(
            title: JustSnapLocalization.localizedString(forKey: "app.name"),
            titleBarHeight: Self.titleBarHeight,
            windowHeight: Self.windowHeight
        ) {
            ManagementCenterView(
                destination: .providerSettings,
                records: [],
                showsGeneralSettings: false,
                providerSettings: ProviderSettingsConfiguration(
                    snapshot: ProviderSetupSnapshot(
                        selectedProvider: .deepSeek,
                        availableModelIDs: ["deepseek-v4-flash-vision-exp"],
                        selectedModelID: "deepseek-v4-flash-vision-exp",
                        phase: .ready,
                        failure: nil
                    ),
                    configurations: configurations,
                    currentProvider: .deepSeek,
                    credentialEditor: editor,
                    pendingModelID: .constant("deepseek-v4-flash-vision-exp"),
                    onSelectProvider: { _ in },
                    onValidate: { _ in },
                    onRefresh: {},
                    onSelectModel: { _ in }
                )
            )
        }
    }
}
