import SwiftUI
import JustSnapCore

public struct TargetLanguageOption: Identifiable, Equatable, Sendable {
    public let code: String
    public let name: String

    public var id: String { code }

    /// What the toolbar and the language list show first (v1-core::REQ-013/AC-03).
    public var abbreviation: String { TargetLanguageCatalog.abbreviation(for: code) }

    public init(code: String, name: String) {
        self.code = code
        self.name = name
    }

    /// The list's search matches the abbreviation or the name (v1-core::REQ-013/AC-04).
    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return true }
        return abbreviation.lowercased().contains(query) || name.lowercased().contains(query)
    }
}

/// What the toolbar shows as operations run, updated in place so an open language list stays open.
@MainActor
public final class CaptureToolbarState: ObservableObject {
    @Published public var targetLanguageCode: String
    /// The operation whose result box is showing.
    @Published public var currentOperation: WorkspaceOperationKind?
    @Published public var isRequestRunning = false
    /// Operations that cannot start now, while a result is unsaved (v1-core::REQ-011/AC-07).
    @Published public var unavailableOperations: Set<WorkspaceOperationKind> = []

    public init(targetLanguageCode: String) {
        self.targetLanguageCode = targetLanguageCode
    }

    func isBlocked(_ operation: WorkspaceOperationKind) -> Bool {
        (isRequestRunning && currentOperation != operation) || unavailableOperations.contains(operation)
    }
}

public struct CaptureOperationToolbar: View {
    @ObservedObject private var state: CaptureToolbarState
    private let targetLanguages: [TargetLanguageOption]
    private let onStart: (WorkspaceOperationKind) -> Void
    private let onTargetLanguageChange: (String) -> Void
    private let onCopy: () -> Void
    private let onSave: () -> Void
    private let onCancel: () -> Void

    public init(
        state: CaptureToolbarState,
        targetLanguages: [TargetLanguageOption],
        onStart: @escaping (WorkspaceOperationKind) -> Void,
        onTargetLanguageChange: @escaping (String) -> Void,
        onCopy: @escaping () -> Void,
        onSave: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.state = state
        self.targetLanguages = targetLanguages
        self.onStart = onStart
        self.onTargetLanguageChange = onTargetLanguageChange
        self.onCopy = onCopy
        self.onSave = onSave
        self.onCancel = onCancel
    }

    public var body: some View {
        HStack(spacing: JustSnapUIConstants.toolbarControlGap) {
            CaptureOperationControls(
                state: state,
                targetLanguages: targetLanguages,
                onStart: onStart,
                onTargetLanguageChange: onTargetLanguageChange
            )
            Divider().frame(height: 19)
            iconButton(JustSnapStrings.copyImage, enabled: !state.isRequestRunning, action: onCopy) {
                JustSnapIcon.copy.image
            }
            iconButton(JustSnapStrings.saveImage, enabled: !state.isRequestRunning, action: onSave) {
                FloppyDiskIcon()
            }
            iconButton(JustSnapStrings.cancel, enabled: true, action: onCancel) {
                JustSnapIcon.close.image
            }
        }
        .padding(JustSnapUIConstants.toolbarPadding)
        .background(.regularMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius: JustSnapUIConstants.compactCornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: JustSnapUIConstants.compactCornerRadius,
                style: .continuous
            )
            .stroke(JustSnapTheme.border, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
        .fixedSize()
    }

    private func iconButton<Icon: View>(
        _ label: String,
        enabled: Bool,
        action: @escaping () -> Void,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        Button(action: action) {
            icon()
                .frame(width: 13, height: 13)
                .frame(
                    width: JustSnapUIConstants.toolbarControlHeight,
                    height: JustSnapUIConstants.toolbarControlHeight
                )
                .foregroundStyle(enabled ? JustSnapTheme.primaryText : JustSnapTheme.tertiaryText)
        }
        // The style makes the whole box take the press, not only the icon's drawn pixels: the floppy
        // disk is a thin outline that a press would mostly miss.
        .buttonStyle(CaptureToolbarButtonStyle(kind: .icon))
        .disabled(!enabled)
        .help(label)
        .accessibilityLabel(label)
    }
}

/// Extract and Translate with its target language: the capture toolbar's operations, which the paste
/// result box also shows in its operation row, without Extract for Pasted Text (clipboard-paste::REQ-006/AC-03).
public struct CaptureOperationControls: View {
    @ObservedObject private var state: CaptureToolbarState
    private let targetLanguages: [TargetLanguageOption]
    private let offersExtract: Bool
    private let onStart: (WorkspaceOperationKind) -> Void
    private let onTargetLanguageChange: (String) -> Void

    public init(
        state: CaptureToolbarState,
        targetLanguages: [TargetLanguageOption],
        offersExtract: Bool = true,
        onStart: @escaping (WorkspaceOperationKind) -> Void,
        onTargetLanguageChange: @escaping (String) -> Void
    ) {
        self.state = state
        self.targetLanguages = targetLanguages
        self.offersExtract = offersExtract
        self.onStart = onStart
        self.onTargetLanguageChange = onTargetLanguageChange
    }

    public var body: some View {
        HStack(spacing: JustSnapUIConstants.toolbarControlGap) {
            if offersExtract { extractButton }
            TranslateControl(
                state: state,
                options: targetLanguages,
                onStart: { onStart(.translate) },
                onTargetLanguageChange: onTargetLanguageChange
            )
        }
    }

    private var extractButton: some View {
        let isCurrent = state.currentOperation == .extract
        let isBlocked = state.isBlocked(.extract)
        return Button {
            onStart(.extract)
        } label: {
            Label(JustSnapStrings.captureExtract, systemImage: JustSnapIcon.extract.rawValue)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 9)
                .frame(height: JustSnapUIConstants.toolbarControlHeight)
                .foregroundStyle(
                    isBlocked ? JustSnapTheme.tertiaryText : isCurrent ? JustSnapTheme.accent : JustSnapTheme.primaryText
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: JustSnapUIConstants.compactCornerRadius,
                        style: .continuous
                    )
                    .stroke(isCurrent ? JustSnapTheme.accent : JustSnapTheme.border, lineWidth: 1)
                }
        }
        // Both actions look alike until the user picks one.
        .buttonStyle(CaptureToolbarButtonStyle(kind: .field, isCurrent: isCurrent))
        .disabled(isBlocked)
    }
}

/// Translate and its target language as one control (v1-core::REQ-013/AC-02).
private struct TranslateControl: View {
    @ObservedObject var state: CaptureToolbarState
    let options: [TargetLanguageOption]
    let onStart: () -> Void
    let onTargetLanguageChange: (String) -> Void
    @State private var isPresented = false
    @State private var searchText = ""

    private var isCurrent: Bool { state.currentOperation == .translate }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: JustSnapUIConstants.compactCornerRadius, style: .continuous)
    }

    private var lineColor: Color {
        isCurrent ? JustSnapTheme.accent : JustSnapTheme.border
    }

    var body: some View {
        HStack(spacing: 0) {
            translateButton
            Rectangle()
                .fill(lineColor)
                .frame(width: 1)
            languageButton
        }
        .frame(height: JustSnapUIConstants.toolbarControlHeight)
        .background(JustSnapTheme.surface)
        .clipShape(shape)
        .overlay { shape.stroke(lineColor, lineWidth: 1) }
    }

    private var translateButton: some View {
        let isBlocked = state.isBlocked(.translate)
        return Button(action: onStart) {
            Label(JustSnapStrings.translate, systemImage: JustSnapIcon.translate.rawValue)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 9)
                .frame(maxHeight: .infinity)
                .foregroundStyle(
                    isBlocked ? JustSnapTheme.tertiaryText : isCurrent ? JustSnapTheme.accent : JustSnapTheme.primaryText
                )
        }
        .buttonStyle(CaptureToolbarButtonStyle(kind: .part, isCurrent: isCurrent))
        .disabled(isBlocked)
    }

    private var languageButton: some View {
        Button {
            searchText = ""
            isPresented.toggle()
        } label: {
            HStack(spacing: 2) {
                Text(TargetLanguageCatalog.abbreviation(for: state.targetLanguageCode))
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .padding(.leading, 6)
            .padding(.trailing, 4)
            .frame(maxHeight: .infinity)
            .foregroundStyle(isCurrent ? JustSnapTheme.accent : JustSnapTheme.secondaryText)
        }
        .buttonStyle(CaptureToolbarButtonStyle(kind: .part, isCurrent: isCurrent))
        .help(selectedLanguageHint)
        .accessibilityLabel(selectedLanguageHint)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            TargetLanguageList(
                options: options,
                selectedCode: state.targetLanguageCode,
                searchText: $searchText
            ) { code in
                state.targetLanguageCode = code
                onTargetLanguageChange(code)
                isPresented = false
            }
        }
    }

    private var selectedLanguageHint: String {
        let name = options.first { $0.code == state.targetLanguageCode }?.name ?? state.targetLanguageCode
        return JustSnapStrings.targetLanguageHint(name)
    }
}

/// The searchable target language list that the toolbar's language part and the menu panel's language row
/// open (v1-core::REQ-013/AC-04, REQ-017/AC-02).
struct TargetLanguageList: View {
    let options: [TargetLanguageOption]
    let selectedCode: String
    @Binding var searchText: String
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 8) {
            TextField(JustSnapStrings.targetLanguageSearch, text: $searchText)
                .textFieldStyle(.roundedBorder)
            List(options.filter { $0.matches(searchText) }) { option in
                Button {
                    onSelect(option.code)
                } label: {
                    HStack(spacing: 8) {
                        Text(option.abbreviation)
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 30, alignment: .leading)
                        Text(option.name)
                            .foregroundStyle(JustSnapTheme.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 0)
                        if selectedCode == option.code {
                            Image(systemName: "checkmark")
                                .foregroundStyle(JustSnapTheme.accent)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
        .padding(10)
        .frame(width: 260, height: 340)
    }
}
