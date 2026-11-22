import AppKit
import SwiftUI
import JustSnapCore

public struct ProviderSettingsFocusRequest: Equatable {
    public let id = UUID()
    public let provider: ProviderID

    public init(provider: ProviderID) { self.provider = provider }
}

public struct ProviderSettingsConfiguration {
    public let snapshot: ProviderSetupSnapshot
    public let focusRequest: ProviderSettingsFocusRequest?
    public let configurations: [ProviderID: ProviderConfiguration]
    public let currentProvider: ProviderID?
    public let credentialEditor: ProviderCredentialEditor
    public let pendingModelID: Binding<String?>
    public let onSelectProvider: (ProviderID) -> Void
    /// The Provider page opened this card, or nil when it shows none.
    public let onOpenProviderCard: (ProviderID?) -> Void
    public let onValidate: (ProviderCredentialSubmission) -> Void
    public let onRefresh: () -> Void
    public let onSelectModel: (String) -> Void
    public let onSetCurrentProvider: (ProviderID) -> Void
    public let onRemoveProvider: (ProviderID) -> Void

    public init(
        snapshot: ProviderSetupSnapshot,
        focusRequest: ProviderSettingsFocusRequest? = nil,
        configurations: [ProviderID: ProviderConfiguration] = [:],
        currentProvider: ProviderID? = nil,
        credentialEditor: ProviderCredentialEditor,
        pendingModelID: Binding<String?>,
        onSelectProvider: @escaping (ProviderID) -> Void,
        onOpenProviderCard: @escaping (ProviderID?) -> Void = { _ in },
        onValidate: @escaping (ProviderCredentialSubmission) -> Void,
        onRefresh: @escaping () -> Void,
        onSelectModel: @escaping (String) -> Void,
        onSetCurrentProvider: @escaping (ProviderID) -> Void = { _ in },
        onRemoveProvider: @escaping (ProviderID) -> Void = { _ in }
    ) {
        self.snapshot = snapshot
        self.focusRequest = focusRequest
        self.configurations = configurations
        self.currentProvider = currentProvider
        self.credentialEditor = credentialEditor
        self.pendingModelID = pendingModelID
        self.onSelectProvider = onSelectProvider
        self.onOpenProviderCard = onOpenProviderCard
        self.onValidate = onValidate
        self.onRefresh = onRefresh
        self.onSelectModel = onSelectModel
        self.onSetCurrentProvider = onSetCurrentProvider
        self.onRemoveProvider = onRemoveProvider
    }
}

private struct ProviderCardOpening: Equatable {
    let provider: ProviderID
    let pageRequest: Int
}

public struct GeneralSettingsSnapshot: Equatable, Sendable {
    public let language: ApplicationLanguagePreference
    public let languageRestartRequired: Bool
    public let loginItemEnabled: Bool
    public let loginItemState: LoginItemState
    public let automaticallyChecksForUpdates: Bool
    public let updateState: UpdateLifecycleState
    public let retentionShorteningRecordCount: Int?
    public let captureShortcut: GlobalShortcut
    public let shortcutFailure: ShortcutSettingsFailure?
    /// Nil when no paste shortcut could be registered at startup (clipboard-paste::REQ-001/AC-04).
    public let pasteShortcut: GlobalShortcut?
    public let pasteShortcutFailure: ShortcutSettingsFailure?

    public init(
        language: ApplicationLanguagePreference = .system,
        languageRestartRequired: Bool = false,
        loginItemEnabled: Bool = true,
        loginItemState: LoginItemState = .enabled,
        automaticallyChecksForUpdates: Bool = true,
        updateState: UpdateLifecycleState = .idle,
        retentionShorteningRecordCount: Int? = nil,
        captureShortcut: GlobalShortcut = .defaultCapture,
        shortcutFailure: ShortcutSettingsFailure? = nil,
        pasteShortcut: GlobalShortcut? = .defaultPaste,
        pasteShortcutFailure: ShortcutSettingsFailure? = nil
    ) {
        self.language = language
        self.languageRestartRequired = languageRestartRequired
        self.loginItemEnabled = loginItemEnabled
        self.loginItemState = loginItemState
        self.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        self.updateState = updateState
        self.retentionShorteningRecordCount = retentionShorteningRecordCount
        self.captureShortcut = captureShortcut
        self.shortcutFailure = shortcutFailure
        self.pasteShortcut = pasteShortcut
        self.pasteShortcutFailure = pasteShortcutFailure
    }
}

public enum ShortcutSettingsFailure: Equatable, Sendable {
    case invalid
    case conflict
    case registrationFailed
    /// A conflict left the paste shortcut unregistered, so there is no previous shortcut still working.
    case unset
}

@MainActor
public struct ManagementCenterCallbacks {
    public let historyRetry: HistoryRetryPresentation
    public let onRetryHistorySave: () -> Void
    public let onSelectRecord: (UUID) -> Void
    public let onRetryRecord: (UUID) -> Void
    public let onSetPinned: (UUID, Bool) -> Void
    public let onDelete: (UUID) -> Void
    public let onClearHistory: (Bool) -> Void
    public let onRetryCleanup: () -> Void
    public let onRetentionChange: (HistoryRetentionPeriod) -> Void
    public let onConfirmRetentionShortening: () -> Void
    public let onCancelRetentionShortening: () -> Void
    public let onLanguageChange: (ApplicationLanguagePreference) -> Void
    public let onRestartForLanguageChange: () -> Void
    public let onLoginItemChange: (Bool) -> Void
    public let onShortcutChange: (GlobalShortcut) -> Void
    public let onPasteShortcutChange: (GlobalShortcut) -> Void
    public let onOpenLoginItemSettings: () -> Void
    public let onAutomaticUpdateChecksChange: (Bool) -> Void
    public let onCheckUpdates: () -> Void
    public let onDownloadUpdate: () -> Void
    public let onOpenUpdateInformation: (URL) -> Void
    public let onInstallUpdate: () -> Void
    public let onExportDiagnostics: () -> Void

    public init(
        historyRetry: HistoryRetryPresentation = HistoryRetryPresentation(),
        onRetryHistorySave: @escaping () -> Void = {},
        onSelectRecord: @escaping (UUID) -> Void = { _ in },
        onRetryRecord: @escaping (UUID) -> Void = { _ in },
        onSetPinned: @escaping (UUID, Bool) -> Void = { _, _ in },
        onDelete: @escaping (UUID) -> Void = { _ in },
        onClearHistory: @escaping (Bool) -> Void = { _ in },
        onRetryCleanup: @escaping () -> Void = {},
        onRetentionChange: @escaping (HistoryRetentionPeriod) -> Void = { _ in },
        onConfirmRetentionShortening: @escaping () -> Void = {},
        onCancelRetentionShortening: @escaping () -> Void = {},
        onLanguageChange: @escaping (ApplicationLanguagePreference) -> Void = { _ in },
        onRestartForLanguageChange: @escaping () -> Void = {},
        onLoginItemChange: @escaping (Bool) -> Void = { _ in },
        onShortcutChange: @escaping (GlobalShortcut) -> Void = { _ in },
        onPasteShortcutChange: @escaping (GlobalShortcut) -> Void = { _ in },
        onOpenLoginItemSettings: @escaping () -> Void = {},
        onAutomaticUpdateChecksChange: @escaping (Bool) -> Void = { _ in },
        onCheckUpdates: @escaping () -> Void = {},
        onDownloadUpdate: @escaping () -> Void = {},
        onOpenUpdateInformation: @escaping (URL) -> Void = { _ in },
        onInstallUpdate: @escaping () -> Void = {},
        onExportDiagnostics: @escaping () -> Void = {}
    ) {
        self.historyRetry = historyRetry
        self.onRetryHistorySave = onRetryHistorySave
        self.onSelectRecord = onSelectRecord
        self.onRetryRecord = onRetryRecord
        self.onSetPinned = onSetPinned
        self.onDelete = onDelete
        self.onClearHistory = onClearHistory
        self.onRetryCleanup = onRetryCleanup
        self.onRetentionChange = onRetentionChange
        self.onConfirmRetentionShortening = onConfirmRetentionShortening
        self.onCancelRetentionShortening = onCancelRetentionShortening
        self.onLanguageChange = onLanguageChange
        self.onRestartForLanguageChange = onRestartForLanguageChange
        self.onLoginItemChange = onLoginItemChange
        self.onShortcutChange = onShortcutChange
        self.onPasteShortcutChange = onPasteShortcutChange
        self.onOpenLoginItemSettings = onOpenLoginItemSettings
        self.onAutomaticUpdateChecksChange = onAutomaticUpdateChecksChange
        self.onCheckUpdates = onCheckUpdates
        self.onDownloadUpdate = onDownloadUpdate
        self.onOpenUpdateInformation = onOpenUpdateInformation
        self.onInstallUpdate = onInstallUpdate
        self.onExportDiagnostics = onExportDiagnostics
    }
}

public struct ManagementCenterView: View {
    @ObservedObject private var historyRetry: HistoryRetryPresentation
    private let requestedDestination: ManagementCenterDestination
    private let navigationRequestID: UUID?
    private let records: [HistoryRecord]
    private let selectedImage: NSImage?
    private let selectedImageLoadFailed: Bool
    private let imageRecordID: UUID?
    private let cleanupFailureCount: Int
    private let callbacks: ManagementCenterCallbacks
    private let settings: GeneralSettingsSnapshot
    private let providerSettings: ProviderSettingsConfiguration?
    @ObservedObject private var credentialEditor: ProviderCredentialEditor
    @State private var destination: ManagementCenterDestination
    @State private var kind: HistoryOperationKindFilter = .all
    @State private var historyProviderID: String?
    @State private var searchText: String
    @State private var selectedRecordID: UUID?
    @FocusState private var historyListFocused: Bool
    @State private var retention: HistoryRetentionPeriod
    @State private var pinnedOnly = false
    @State private var showGeneralSettings = false
    @State private var pendingDeletion: HistoryRecord?
    @State private var showingClearConfirmation = false
    @State private var expandedProvider: ProviderID?
    @State private var providerPageRequests = 0
    @State private var showsAPIKey = false
    @State private var providerPendingRemoval: ProviderID?
    @State private var previewImage: HistoryPreviewImage?

    public init(
        destination: ManagementCenterDestination,
        navigationRequestID: UUID? = nil,
        records: [HistoryRecord],
        selectedRecordID: UUID? = nil,
        selectedImage: NSImage? = nil,
        selectedImageLoadFailed: Bool = false,
        cleanupFailureCount: Int = 0,
        searchText: String = "",
        showsGeneralSettings: Bool? = nil,
        retention: HistoryRetentionPeriod = .thirtyDays,
        settings: GeneralSettingsSnapshot = GeneralSettingsSnapshot(),
        providerSettings: ProviderSettingsConfiguration? = nil,
        callbacks: ManagementCenterCallbacks = ManagementCenterCallbacks()
    ) {
        self.requestedDestination = destination
        self.navigationRequestID = navigationRequestID
        self.records = records
        self.selectedImage = selectedImage
        self.selectedImageLoadFailed = selectedImageLoadFailed
        self.imageRecordID = selectedRecordID ?? records.first?.id
        self.cleanupFailureCount = cleanupFailureCount
        self.callbacks = callbacks
        _historyRetry = ObservedObject(wrappedValue: callbacks.historyRetry)
        self.settings = settings
        self.providerSettings = providerSettings
        _credentialEditor = ObservedObject(wrappedValue: providerSettings?.credentialEditor ?? ProviderCredentialEditor())
        _destination = State(initialValue: destination)
        _selectedRecordID = State(initialValue: selectedRecordID ?? records.first?.id)
        _searchText = State(initialValue: searchText)
        _retention = State(initialValue: retention)
        _showGeneralSettings = State(
            initialValue: showsGeneralSettings ?? (destination == .settings)
        )
        _expandedProvider = State(
            initialValue: providerSettings.map {
                ProviderSettingsInitialSelection.resolve(
                    explicitTarget: $0.focusRequest?.provider ?? (destination == .providerSettings
                        ? $0.snapshot.selectedProvider
                        : nil),
                    currentProvider: $0.currentProvider
                )
            }
        )
    }

    public var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(spacing: 0) {
                contentToolbar
                Divider()
                if destination == .history { historyContent } else { settingsContent }
            }
        }
        .background(JustSnapTheme.window)
        .frame(minWidth: 920, minHeight: 620)
        .sheet(item: $previewImage) { item in
            HistoryImagePreview(image: item.image)
        }
        .onChange(of: filteredRecords.map(\.id), initial: true) { _, _ in reconcileHistorySelection() }
        .onChange(of: selectedRecordID, initial: true) { _, value in
            if let value { callbacks.onSelectRecord(value) }
        }
        .onChange(of: navigationRequestID) { _, _ in
            destination = requestedDestination
            showGeneralSettings = requestedDestination == .settings
            if requestedDestination == .providerSettings {
                providerPageRequests += 1
                openInitialProviderIfNeeded()
            }
        }
        .confirmationDialog(
            JustSnapStrings.historyDeleteConfirm,
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            presenting: pendingDeletion
        ) { record in
            Button(JustSnapStrings.historyDelete, role: .destructive) {
                callbacks.onDelete(record.id)
                pendingDeletion = nil
            }
        }
        .confirmationDialog(
            JustSnapStrings.historyClearConfirm,
            isPresented: $showingClearConfirmation
        ) {
            Button(JustSnapStrings.historyClearUnpinned, role: .destructive) {
                callbacks.onClearHistory(false)
            }
            Button(JustSnapStrings.historyClearIncludingPinned, role: .destructive) {
                callbacks.onClearHistory(true)
            }
        }
        .confirmationDialog(
            retentionShorteningTitle,
            isPresented: Binding(
                get: { settings.retentionShorteningRecordCount != nil },
                set: { if !$0 { callbacks.onCancelRetentionShortening() } }
            )
        ) {
            Button(
                JustSnapStrings.historyRetentionShorteningAction,
                role: .destructive,
                action: callbacks.onConfirmRetentionShortening
            )
        }
        .confirmationDialog(
            JustSnapStrings.providerRemoveConfirmation,
            isPresented: Binding(
                get: { providerPendingRemoval != nil },
                set: { if !$0 { providerPendingRemoval = nil } }
            ),
            presenting: providerPendingRemoval
        ) { provider in
            Button(JustSnapStrings.providerRemove, role: .destructive) {
                providerSettings?.onRemoveProvider(provider)
                showsAPIKey = false
                providerPendingRemoval = nil
            }
        }
        .onChange(of: credentialEditor.provider) { _, _ in
            showsAPIKey = false
        }
        .onChange(of: providerSettings?.focusRequest) { _, request in
            guard let request else { return }
            destination = .providerSettings
            showGeneralSettings = false
            expandedProvider = request.provider
            showsAPIKey = false
        }
        .onChange(of: providerCardOpening, initial: true) { _, opening in
            guard let providerSettings else { return }
            // Another page can leave this card expanded and not loaded. A press on it has already begun its load.
            if let provider = opening?.provider,
               providerSettings.snapshot.selectedProvider != provider,
               credentialEditor.provider != provider {
                providerSettings.onSelectProvider(provider)
            }
            providerSettings.onOpenProviderCard(opening?.provider)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            sidebarHeading(JustSnapStrings.historyLibrary)
            navButton(JustSnapStrings.menuHistory, icon: .history, count: records.count, selected: destination == .history && !pinnedOnly) {
                destination = .history
                pinnedOnly = false
            }
            navButton(JustSnapStrings.historyPinned, icon: .pinned, count: records.filter(\.isPinned).count, selected: destination == .history && pinnedOnly) {
                destination = .history
                pinnedOnly = true
            }
            sidebarHeading(JustSnapStrings.menuSettings)
            navButton(JustSnapStrings.historyProviderSettings, icon: .providerList, count: ProviderID.allCases.count, selected: destination == .providerSettings) {
                destination = .providerSettings
                showGeneralSettings = false
                openInitialProviderIfNeeded()
            }
            navButton(JustSnapStrings.historyGeneralSettings, icon: .general, selected: destination == .settings) {
                destination = .settings
                showGeneralSettings = true
            }
            Spacer()
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 12)
        .frame(width: ManagementCenterMetrics.sidebarWidth)
        .background(JustSnapTheme.subtleSurface)
    }

    private var contentToolbar: some View {
        HStack(spacing: 12) {
            if destination == .history {
                HStack(spacing: 2) {
                    historyTypeButton(JustSnapStrings.historyAll, kind: .all)
                    historyTypeButton(JustSnapStrings.historyExtract, kind: .extract)
                    historyTypeButton(JustSnapStrings.translate, kind: .translate)
                }
                .padding(3)
                .background(JustSnapTheme.subtleSurface, in: RoundedRectangle(cornerRadius: 8))
                .accessibilityElement(children: .contain)
                .accessibilityLabel(JustSnapStrings.operationSelector)
                Picker(JustSnapStrings.historyProviderSettings, selection: $historyProviderID) {
                    Text(JustSnapStrings.historyAllProviders).tag(String?.none)
                    ForEach(historyProviderOptions, id: \.self) { providerID in
                        Text(historyProviderName(providerID)).tag(Optional(providerID))
                    }
                }
                .labelsHidden()
                .frame(width: 145)
                HStack(spacing: 7) {
                    JustSnapIcon.search.image.foregroundStyle(JustSnapTheme.secondaryText)
                    TextField(JustSnapStrings.historySearch, text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 9)
                .frame(minWidth: 110, maxWidth: .infinity)
                .frame(height: 31)
                .background(JustSnapTheme.surface, in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(JustSnapTheme.border))
            } else {
                Text(JustSnapStrings.menuSettings).font(.headline)
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .frame(height: destination == .history ? 58 : ManagementCenterMetrics.titlebarHeight)
    }

    private func historyTypeButton(_ title: String, kind value: HistoryOperationKindFilter) -> some View {
        Button(title) { kind = value }
            .buttonStyle(HistoryTypeButtonStyle(isSelected: kind == value))
            .accessibilityAddTraits(kind == value ? .isSelected : [])
    }

    private var historyProviderOptions: [String] {
        var values = Set(records.map { $0.operation.selection.providerID })
        // Keep an active filter visible if its last record is removed.
        if let historyProviderID { values.insert(historyProviderID) }
        return values.sorted()
    }

    private func historyProviderName(_ id: String) -> String {
        ProviderID(rawValue: id).map(JustSnapStrings.providerName) ?? id
    }

    private var historyContent: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                if cleanupFailureCount > 0 {
                    Button(action: callbacks.onRetryCleanup) {
                        Label(JustSnapStrings.historyCleanupFailures, systemImage: JustSnapIcon.warningBadge.rawValue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(JustSnapTheme.warning)
                    .padding(10)
                }
                if filteredRecords.isEmpty {
                    ContentUnavailableView(
                        JustSnapStrings.historyEmptyTitle,
                        systemImage: JustSnapIcon.search.rawValue,
                        description: Text(JustSnapStrings.historyEmptyBody)
                    )
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 5) {
                                ForEach(filteredRecords) { record in
                                    Button {
                                        selectedRecordID = record.id
                                        historyListFocused = true
                                    } label: {
                                        historyRow(record)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .modifier(HistoryRecordSurface(isSelected: selectedRecordID == record.id))
                                    }
                                    .buttonStyle(.plain)
                                    .focusable(false)
                                    .id(record.id)
                                    .accessibilityElement(children: .combine)
                                    .accessibilityIdentifier("history-record-\(record.id)")
                                    .accessibilityAddTraits(selectedRecordID == record.id ? .isSelected : [])
                                    .accessibilityAction {
                                        selectedRecordID = record.id
                                        historyListFocused = true
                                    }
                                }
                            }
                            .padding(5)
                        }
                        .background(JustSnapTheme.historySurface)
                        .focusable()
                        .focusEffectDisabled()
                        .focused($historyListFocused)
                        .onKeyPress(keys: [.upArrow, .downArrow], phases: [.down, .repeat]) { press in
                            guard press.modifiers.intersection([.shift, .control, .option, .command]).isEmpty,
                                  let index = filteredRecords.firstIndex(where: { $0.id == selectedRecordID }) else { return .ignored }
                            let next = max(0, min(filteredRecords.count - 1, index + (press.key == .downArrow ? 1 : -1)))
                            selectedRecordID = filteredRecords[next].id
                            proxy.scrollTo(filteredRecords[next].id)
                            return .handled
                        }
                    }
                }
                Divider()
                Button(JustSnapStrings.historyClear) { showingClearConfirmation = true }
                    .buttonStyle(.plain)
                    .disabled(historyRetry.preventsDiscard)
                    .foregroundStyle(JustSnapTheme.destructive)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 259)
            Rectangle().fill(JustSnapTheme.historyDivider).frame(width: 1)
            detail
        }
    }

    @ViewBuilder
    private var settingsContent: some View {
        if showGeneralSettings {
            Form {
                Section {
                    settingsRow(
                        title: JustSnapStrings.languageTitle,
                        detail: JustSnapStrings.languageHint
                    ) {
                        Picker("", selection: languageBinding) {
                            Text(JustSnapStrings.languageSystem)
                                .tag(ApplicationLanguagePreference.system)
                            Text(JustSnapStrings.languageSimplifiedChinese)
                                .tag(ApplicationLanguagePreference.simplifiedChinese)
                            Text(JustSnapStrings.languageEnglish)
                                .tag(ApplicationLanguagePreference.english)
                        }
                        .labelsHidden()
                        .frame(width: 180)
                    }
                    if settings.languageRestartRequired {
                        settingsRow(
                            title: JustSnapStrings.languageRestartRequired,
                            detail: JustSnapStrings.languageRestartHint
                        ) {
                            Button(
                                JustSnapStrings.restart,
                                action: callbacks.onRestartForLanguageChange
                            )
                        }
                    }
                    settingsRow(
                        title: JustSnapStrings.shortcutTitle,
                        detail: JustSnapStrings.shortcutHint
                    ) {
                        GlobalShortcutRecorder(
                            shortcut: settings.captureShortcut,
                            onChange: callbacks.onShortcutChange
                        )
                        .frame(width: 150, height: 28)
                    }
                    if let shortcutFailure = settings.shortcutFailure {
                        Text(JustSnapStrings.shortcutFailure(shortcutFailure))
                            .font(.caption)
                            .foregroundStyle(JustSnapTheme.destructive)
                    }
                    settingsRow(
                        title: JustSnapStrings.pasteShortcutTitle,
                        detail: JustSnapStrings.shortcutHint
                    ) {
                        GlobalShortcutRecorder(
                            shortcut: settings.pasteShortcut,
                            onChange: callbacks.onPasteShortcutChange
                        )
                        .frame(width: 150, height: 28)
                    }
                    if let pasteShortcutFailure = settings.pasteShortcutFailure {
                        Text(JustSnapStrings.shortcutFailure(pasteShortcutFailure))
                            .font(.caption)
                            .foregroundStyle(JustSnapTheme.destructive)
                    }
                    settingsRow(
                        title: JustSnapStrings.loginItemTitle,
                        detail: JustSnapStrings.loginItemHint
                    ) {
                        Toggle("", isOn: loginItemBinding).labelsHidden()
                    }
                    if settings.loginItemState == .requiresApproval {
                        Button(
                            JustSnapStrings.loginItemApproval,
                            action: callbacks.onOpenLoginItemSettings
                        )
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(JustSnapStrings.historyGeneralSettings)
                        Text(JustSnapStrings.generalSettingsSubtitle)
                            .font(.caption)
                            .foregroundStyle(JustSnapTheme.secondaryText)
                    }
                }
                Section(JustSnapStrings.updateSection) {
                    settingsRow(
                        title: JustSnapStrings.updateAutomaticChecks,
                        detail: JustSnapStrings.updateAutomaticChecksHint
                    ) {
                        Toggle("", isOn: automaticChecksBinding).labelsHidden()
                    }
                    updateStatus
                }
                Section(JustSnapStrings.historyRetention) {
                    Picker(JustSnapStrings.historyRetention, selection: $retention) {
                        ForEach(HistoryRetentionPeriod.allCases, id: \.self) { period in
                            Text(String(format: JustSnapStrings.historyRetentionDaysFormat, period.rawValue))
                                .tag(period)
                        }
                    }
                    .onChange(of: retention) { _, value in callbacks.onRetentionChange(value) }
                    Text(JustSnapStrings.historyRetentionHint)
                        .foregroundStyle(JustSnapTheme.secondaryText)
                }
                Section(JustSnapStrings.diagnosticsSection) {
                    settingsRow(
                        title: JustSnapStrings.diagnosticsTitle,
                        detail: JustSnapStrings.diagnosticsHint
                    ) {
                        Button(
                            JustSnapStrings.diagnosticsExport,
                            action: callbacks.onExportDiagnostics
                        )
                    }
                }
            }
            .formStyle(.grouped)
            .padding(18)
        } else {
            providerSettingsContent
        }
    }

    private var providerSettingsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(JustSnapStrings.historyProviderSettings)
                        .font(.title3.weight(.semibold))
                    Text(JustSnapStrings.providerSetupSubtitle)
                        .font(.callout)
                        .foregroundStyle(JustSnapTheme.secondaryText)
                }
                VStack(spacing: 12) {
                    ForEach([ProviderID.deepSeek, .openAI, .gemini], id: \.self) { provider in
                        providerSettingsCard(provider)
                    }
                }
            }
            .frame(maxWidth: ManagementCenterMetrics.providerContentWidth)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .background(JustSnapTheme.subtleSurface)
    }

    private func providerSettingsCard(_ provider: ProviderID) -> some View {
        let isExpanded = expandedProvider == provider
        return VStack(spacing: 0) {
            Button {
                if isExpanded {
                    expandedProvider = nil
                    credentialEditor.close()
                } else {
                    expandedProvider = provider
                    showsAPIKey = false
                    providerSettings?.onSelectProvider(provider)
                }
            } label: {
                HStack(spacing: 14) {
                    ProviderIdentityMark(provider: provider)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(JustSnapStrings.providerName(provider))
                            .font(.headline)
                        Text(providerCardSubtitle(provider))
                            .font(.caption)
                            .foregroundStyle(JustSnapTheme.secondaryText)
                    }
                    Spacer()
                    providerStatusBadge(provider)
                    JustSnapIcon.chevronDown.image
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(JustSnapTheme.secondaryText)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .frame(minHeight: ManagementCenterMetrics.providerHeaderHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(providerSettings == nil)

            if isExpanded {
                Divider()
                providerEditor(provider)
            }
        }
        .background(JustSnapTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(JustSnapTheme.border.opacity(0.8))
        }
    }

    @ViewBuilder
    private func providerEditor(_ provider: ProviderID) -> some View {
        if let providerSettings,
           providerSettings.snapshot.selectedProvider == provider {
            let presentation = providerCredentialPresentation(provider)
            VStack(alignment: .leading, spacing: 12) {
                if providerSettings.snapshot.blocksConfigurationChanges,
                   providerSettings.snapshot.refreshingProvider == nil,
                   providerSettings.snapshot.phase != .recovering,
                   providerSettings.snapshot.failure != .secureStorage {
                    Label(
                        JustSnapStrings.providerReadOnly,
                        systemImage: JustSnapIcon.lock.rawValue
                    )
                    .font(.callout)
                    .foregroundStyle(JustSnapTheme.secondaryText)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(JustSnapTheme.subtleSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                providerConfigurationFields(
                    providerSettings,
                    presentation: presentation
                )

                HStack {
                    if providerSettings.configurations[provider] != nil {
                        Button(JustSnapStrings.providerRemove, role: .destructive) {
                            providerPendingRemoval = provider
                        }
                        .buttonStyle(SetupActionButtonStyle(isDestructive: true))
                        .disabled(providerSettings.snapshot.blocksConfigurationChanges
                                  || credentialEditor.isSubmitting || credentialEditor.isLoading)
                    }
                    Spacer()
                    if providerSettings.currentProvider == provider {
                        Text(JustSnapStrings.providerCurrent)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(JustSnapTheme.success)
                    } else if providerIsReady(provider) {
                        Button(JustSnapStrings.providerSetCurrent) {
                            providerSettings.onSetCurrentProvider(provider)
                        }
                        .buttonStyle(SetupActionButtonStyle(horizontalPadding: 12))
                        .disabled(providerSettings.snapshot.blocksConfigurationChanges
                                  || credentialEditor.isSubmitting || credentialEditor.isLoading)
                    }
                }
                .frame(minHeight: 32)
            }
            .padding(16)
            .background(JustSnapTheme.subtleSurface)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(24)
        }
    }

    @ViewBuilder
    private func providerConfigurationFields(
        _ providerSettings: ProviderSettingsConfiguration,
        presentation: ProviderInlineCredentialPresentation
    ) -> some View {
        if providerSettings.snapshot.availableModelIDs.isEmpty {
            providerCredentialField(providerSettings, presentation: presentation)
        } else {
            ProviderFieldLayout {
                providerCredentialField(providerSettings, presentation: presentation)
                providerModelField(providerSettings)
            }
        }
    }

    private func providerCredentialField(
        _ providerSettings: ProviderSettingsConfiguration,
        presentation: ProviderInlineCredentialPresentation
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(JustSnapStrings.apiKey)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(JustSnapTheme.secondaryText)
                Spacer()
                Label(
                    providerCredentialStatusText(presentation.status),
                    systemImage: providerCredentialStatusIcon(presentation.status)
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(providerCredentialStatusColor(presentation.status))
            }
            .frame(height: 18)
            HStack(spacing: 0) {
                ProviderAPIKeyField(
                    text: providerAPIKeyBinding,
                    placeholder: JustSnapStrings.apiKeyPlaceholder,
                    isRevealed: showsAPIKey,
                    isEnabled: !providerSettings.snapshot.isReadOnly
                        && !credentialEditor.isSubmitting && !credentialEditor.isLoading,
                    onSubmit: {
                        if presentation.canValidate {
                            credentialEditor.submit(for: providerSettings.snapshot.selectedProvider,
                                                    isReadOnly: providerSettings.snapshot.blocksConfigurationChanges,
                                                    operation: providerSettings.onValidate)
                        }
                    }
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 8)
                Button {
                    providerAPIKeyBinding.wrappedValue = ""
                } label: {
                    JustSnapIcon.close.image.frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(
                    credentialEditor.value.isEmpty
                        || providerSettings.snapshot.isReadOnly || credentialEditor.isSubmitting
                        || credentialEditor.isLoading
                )
                .accessibilityLabel(JustSnapStrings.clearAPIKey)
                Button {
                    showsAPIKey.toggle()
                } label: {
                    (showsAPIKey ? JustSnapIcon.eyeSlash : JustSnapIcon.eye)
                        .image.frame(width: 28, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(providerSettings.snapshot.isReadOnly || credentialEditor.isSubmitting
                          || credentialEditor.isLoading)
                .accessibilityLabel(
                    showsAPIKey
                        ? JustSnapStrings.hideAPIKey
                        : JustSnapStrings.showAPIKey
                )
            }
            .padding(.horizontal, 11)
            .frame(height: ManagementCenterMetrics.providerCredentialFieldHeight)
            .background(JustSnapTheme.window)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(JustSnapTheme.border)
            }

            if presentation.showsValidation {
                HStack {
                    Text(presentation.localInputHint ?? providerValidationHint(presentation.status))
                        .font(.caption)
                        .foregroundStyle(JustSnapTheme.secondaryText)
                    Spacer()
                    Button(JustSnapStrings.validate) {
                        credentialEditor.submit(for: providerSettings.snapshot.selectedProvider,
                                                    isReadOnly: providerSettings.snapshot.blocksConfigurationChanges,
                                                    operation: providerSettings.onValidate)
                    }
                        .buttonStyle(.borderedProminent)
                        .disabled(!presentation.canValidate)
                }
            }
            if let failure = providerSettings.snapshot.failure {
                Label(
                    providerFailureText(failure),
                    systemImage: JustSnapIcon.warning.rawValue
                )
                .font(.callout)
                .foregroundStyle(JustSnapTheme.destructive)
            }
            Text(JustSnapStrings.providerReplacementHint)
                .font(.caption)
                .foregroundStyle(JustSnapTheme.secondaryText)
        }
    }

    private func providerModelField(
        _ providerSettings: ProviderSettingsConfiguration
    ) -> some View {
        let isRefreshing = providerSettings.snapshot.refreshingProvider
            == providerSettings.snapshot.selectedProvider
        let refreshFailed = providerSettings.snapshot.modelRefreshFailure != nil
        return VStack(alignment: .leading, spacing: 6) {
            Text(JustSnapStrings.currentModel).font(.system(size: 13))
                .frame(height: 18)
            HStack(spacing: 8) {
                ProviderModelPicker(
                    modelIDs: providerSettings.snapshot.availableModelIDs,
                    selection: providerModelBinding
                )
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(JustSnapTheme.surface, in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(JustSnapTheme.border))
                .disabled(providerSettings.snapshot.blocksConfigurationChanges
                                  || credentialEditor.isSubmitting || credentialEditor.isLoading)
                Button(action: providerSettings.onRefresh) {
                    HStack(spacing: 6) {
                        if isRefreshing {
                            ProgressView().controlSize(.small)
                        }
                        Text(isRefreshing
                             ? JustSnapStrings.refreshingModels
                             : (refreshFailed ? JustSnapStrings.retryModelRefresh : JustSnapStrings.refresh))
                    }
                    .frame(width: 128)
                }
                    .buttonStyle(SetupActionButtonStyle())
                    .disabled(providerSettings.snapshot.blocksConfigurationChanges
                                  || credentialEditor.isSubmitting || credentialEditor.isLoading)
            }
            // Both messages share a content-sized row; no separate blank error slot.
            ZStack(alignment: .topLeading) {
                Text(JustSnapStrings.visionValidationHint)
                    .foregroundStyle(JustSnapTheme.secondaryText)
                    .opacity(refreshFailed ? 0 : 1)
                    .accessibilityHidden(refreshFailed)
                Text(JustSnapStrings.modelRefreshFailureHint)
                    .foregroundStyle(JustSnapTheme.destructive)
                    .opacity(refreshFailed ? 1 : 0)
                    .accessibilityHidden(!refreshFailed)
            }
            .font(.caption)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var providerAPIKeyBinding: Binding<String> {
        Binding(
            get: { credentialEditor.value },
            set: { credentialEditor.edit($0) }
        )
    }

    private var providerModelBinding: Binding<String?> {
        Binding(
            get: { providerSettings?.pendingModelID.wrappedValue },
            set: { value in
                providerSettings?.pendingModelID.wrappedValue = value
                if let value { providerSettings?.onSelectModel(value) }
            }
        )
    }

    private func providerIsReady(_ provider: ProviderID) -> Bool {
        guard let providerSettings else { return false }
        return ProviderSettingsDetailPresentation(
            provider: provider,
            snapshot: providerSettings.snapshot,
            configurations: providerSettings.configurations
        ).isConfigured
    }

    private func providerCredentialPresentation(
        _ provider: ProviderID
    ) -> ProviderInlineCredentialPresentation {
        guard let providerSettings else {
            return ProviderInlineCredentialPresentation(
                isConfigured: false,
                isSelected: false,
                isDirty: false,
                phase: .awaitingValidation,
                hasAPIKey: false,
                isReadOnly: false
            )
        }
        return ProviderInlineCredentialPresentation(
            isConfigured: providerSettings.configurations[provider] != nil,
            isSelected: providerSettings.snapshot.selectedProvider == provider,
            isDirty: providerSettings.snapshot.selectedProvider == provider
                && credentialEditor.isDirty,
            phase: credentialEditor.isSubmitting ? .validating : providerSettings.snapshot.phase,
            hasAPIKey: !credentialEditor.value.isEmpty,
            isReadOnly: providerSettings.snapshot.isReadOnly
                || credentialEditor.isLoading || credentialEditor.provider != provider,
            isValidationBlocked: providerSettings.snapshot.blocksConfigurationChanges,
            inputIssue: ProviderAPIKeyInput.issue(in: credentialEditor.value),
            failure: providerSettings.snapshot.failure
        )
    }

    private func providerStatusBadge(_ provider: ProviderID) -> some View {
        let status = providerCardPresentation(provider).status
        return Text(providerCardStatusText(status))
            .font(.caption.weight(.semibold))
            .foregroundStyle(providerCardStatusColor(status))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(providerCardStatusColor(status).opacity(0.1))
            .clipShape(Capsule())
    }

    private func providerCardPresentation(
        _ provider: ProviderID
    ) -> ProviderInlineCardPresentation {
        guard let providerSettings else {
            return ProviderInlineCardPresentation(
                provider: provider,
                snapshot: ProviderSetupSnapshot(
                    selectedProvider: .deepSeek,
                    availableModelIDs: [],
                    selectedModelID: nil,
                    phase: .awaitingValidation,
                    failure: nil
                ),
                configuration: nil,
                isDirty: false
            )
        }
        return ProviderInlineCardPresentation(
            provider: provider,
            snapshot: providerSettings.snapshot,
            configuration: providerSettings.configurations[provider],
            isDirty: providerSettings.snapshot.selectedProvider == provider
                && credentialEditor.isDirty
        )
    }

    private func providerCardSubtitle(_ provider: ProviderID) -> String {
        let state = providerStatusDetail(provider)
        if providerSettings?.currentProvider == provider {
            return String(format: JustSnapStrings.providerCurrentDetailFormat, state)
        }
        return state
    }

    private func providerStatusDetail(_ provider: ProviderID) -> String {
        guard let providerSettings else { return JustSnapStrings.notConfigured }
        return ProviderSettingsDetailPresentation(
            provider: provider,
            snapshot: providerSettings.snapshot,
            configurations: providerSettings.configurations
        ).detail
    }

    private func providerCredentialStatusText(
        _ status: ProviderInlineCredentialStatus
    ) -> String {
        switch status {
        case .notConfigured: JustSnapStrings.notConfigured
        case .pending: JustSnapStrings.providerPendingValidation
        case .validating: JustSnapStrings.validating
        case .recovering: JustSnapStrings.recovering
        case .storageFailure: JustSnapStrings.providerStorageFailure
        case .configured: JustSnapStrings.configured
        case .failed: JustSnapStrings.failed
        }
    }

    private func providerCardStatusText(_ status: ProviderInlineCardStatus) -> String {
        switch status {
        case .notConfigured: JustSnapStrings.providerSetupRequired
        case .pendingValidation: JustSnapStrings.providerPendingValidation
        case .validating: JustSnapStrings.validating
        case .recovering: JustSnapStrings.recovering
        case .storageFailure: JustSnapStrings.providerStorageFailure
        case .pendingModel: JustSnapStrings.modelPending
        case .ready: JustSnapStrings.providerAvailable
        case .failed: JustSnapStrings.failed
        }
    }

    private func providerCredentialStatusIcon(
        _ status: ProviderInlineCredentialStatus
    ) -> String {
        switch status {
        case .configured: JustSnapIcon.complete.rawValue
        case .validating, .recovering: JustSnapIcon.retry.rawValue
        case .notConfigured, .pending, .failed, .storageFailure: JustSnapIcon.warningBadge.rawValue
        }
    }

    private func providerCredentialStatusColor(
        _ status: ProviderInlineCredentialStatus
    ) -> Color {
        switch status {
        case .configured: JustSnapTheme.success
        case .failed, .storageFailure: JustSnapTheme.destructive
        case .notConfigured, .pending, .validating, .recovering: JustSnapTheme.warning
        }
    }

    private func providerCardStatusColor(_ status: ProviderInlineCardStatus) -> Color {
        switch status {
        case .ready: JustSnapTheme.success
        case .failed, .storageFailure: JustSnapTheme.destructive
        case .notConfigured, .pendingValidation, .validating, .recovering, .pendingModel:
            JustSnapTheme.warning
        }
    }

    private func providerValidationHint(
        _ status: ProviderInlineCredentialStatus
    ) -> String {
        switch status {
        case .pending: JustSnapStrings.providerNewKeyPending
        case .validating: JustSnapStrings.validating
        case .recovering: JustSnapStrings.recovering
        case .storageFailure: JustSnapStrings.providerStorageFailure
        case .failed: JustSnapStrings.providerRetryValidation
        case .notConfigured: JustSnapStrings.providerEnterKey
        case .configured: ""
        }
    }

    private func providerFailureText(_ failure: ProviderSetupFailure) -> String {
        switch failure {
        case .configurationLocked: JustSnapStrings.providerReadOnly
        case .invalidConfiguration:
            JustSnapStrings.failureMessage(code: "invalid_credential")
        case .incompatibleModel:
            JustSnapStrings.failureMessage(code: "image_input_unsupported")
        case .secureStorage:
            providerSettings?.snapshot.isReadOnly == true
                ? JustSnapStrings.providerStorageReadFailure
                : JustSnapStrings.failureMessage(code: "local_storage")
        case .unavailable:
            JustSnapStrings.failureMessage(code: "provider_unavailable")
        }
    }

    /// Changes when the Provider page opens a card, including when the window is shown again on the same one.
    private var providerCardOpening: ProviderCardOpening? {
        guard destination == .providerSettings, !showGeneralSettings, let expandedProvider else { return nil }
        return ProviderCardOpening(provider: expandedProvider, pageRequest: providerPageRequests)
    }

    private func openInitialProviderIfNeeded() {
        guard expandedProvider == nil, let providerSettings else { return }
        let provider = ProviderSettingsInitialSelection.resolve(
            explicitTarget: nil,
            currentProvider: providerSettings.currentProvider
        )
        expandedProvider = provider
        providerSettings.onSelectProvider(provider)
    }

    private var languageBinding: Binding<ApplicationLanguagePreference> {
        Binding(
            get: { settings.language },
            set: { value in callbacks.onLanguageChange(value) }
        )
    }

    private var loginItemBinding: Binding<Bool> {
        Binding(
            get: { settings.loginItemEnabled },
            set: { value in callbacks.onLoginItemChange(value) }
        )
    }

    private var automaticChecksBinding: Binding<Bool> {
        Binding(
            get: { settings.automaticallyChecksForUpdates },
            set: { value in callbacks.onAutomaticUpdateChecksChange(value) }
        )
    }

    private func settingsRow<Accessory: View>(
        title: String,
        detail: String,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).fontWeight(.semibold)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(JustSnapTheme.secondaryText)
            }
            Spacer()
            accessory()
        }
        .padding(.vertical, 4)
    }

    private var updateStatus: some View {
        HStack(spacing: 12) {
            updateStatusIcon.frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(updateStatusTitle).fontWeight(.semibold)
                Text(updateStatusDetail)
                    .font(.caption)
                    .foregroundStyle(JustSnapTheme.secondaryText)
            }
            Spacer()
            updateStatusAction
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var updateStatusIcon: some View {
        switch settings.updateState {
        case .checking, .downloading:
            ProgressView().controlSize(.small)
        case .readyToInstall:
            JustSnapIcon.downloaded.image.foregroundStyle(JustSnapTheme.accent)
        case .failed:
            JustSnapIcon.warningBadge.image.foregroundStyle(JustSnapTheme.destructive)
        default:
            JustSnapIcon.update.image.foregroundStyle(JustSnapTheme.accent)
        }
    }

    @ViewBuilder
    private var updateStatusAction: some View {
        switch settings.updateState {
        case .available:
            Button(JustSnapStrings.updateDownload, action: callbacks.onDownloadUpdate)
                .buttonStyle(.borderedProminent)
        case .readyToInstall:
            Button(JustSnapStrings.updateInstallNow, action: callbacks.onInstallUpdate)
                .buttonStyle(.borderedProminent)
        case .checking, .downloading:
            EmptyView()
        case .failed:
            Button(JustSnapStrings.updateRetry, action: callbacks.onCheckUpdates)
        default:
            Button(JustSnapStrings.updateCheck, action: callbacks.onCheckUpdates)
        }
    }

    private var updateStatusTitle: String {
        switch settings.updateState {
        case .idle, .current: JustSnapStrings.updateCurrent
        case .checking: JustSnapStrings.updateChecking
        case let .available(version):
            String(format: JustSnapStrings.updateAvailableTitleFormat, version.displayVersion)
        case let .downloading(version, _, _):
            String(format: JustSnapStrings.updateDownloadingTitleFormat, version.displayVersion)
        case let .readyToInstall(version):
            String(format: JustSnapStrings.updateReadyTitleFormat, version.displayVersion)
        case .failed: JustSnapStrings.updateFailedTitle
        }
    }

    private var updateStatusDetail: String {
        switch settings.updateState {
        case .idle, .current: JustSnapStrings.updateAutomaticChecksHint
        case .checking: JustSnapStrings.updateAutomaticChecksHint
        case .available: JustSnapStrings.updateAvailableDetail
        case .downloading: JustSnapStrings.updateDownloadingDetail
        case .readyToInstall: JustSnapStrings.updateReadyDetail
        case let .failed(_, _, message): JustSnapStrings.updateFailedDetail(message: message)
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let record = selectedRecord {
            ScrollView {
                VStack(spacing: 0) {
                    historyDetailHeader(record)
                    Divider()
                    VStack(alignment: .leading, spacing: 18) {
                        if let pastedText = record.operation.pastedText {
                            HistoryPastedTextView(text: pastedText)
                                .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 100)
                                .background(JustSnapTheme.subtleSurface)
                                .clipShape(RoundedRectangle(cornerRadius: JustSnapUIConstants.cardCornerRadius))
                                .overlay {
                                    RoundedRectangle(cornerRadius: JustSnapUIConstants.cardCornerRadius)
                                        .strokeBorder(JustSnapTheme.historyImageBorder, lineWidth: 1)
                                }
                        } else {
                            screenshot(record)
                        }
                        Divider()
                        if historyRetry.recordID == record.id {
                            historyRetryContent(record)
                            if historyRetry.slot.attempt == .succeeded { metrics(record) }
                        }
                        if historyRetry.recordID != record.id || (!historyRetry.isRunning
                            && historyRetry.slot.attempt != .succeeded && historyRetry.slot.unsavedResult == nil) {
                            historyResult(record, source: record.operation.sourceMarkdown,
                                          translation: record.operation.translationMarkdown, segments: record.operation.segments)
                            metrics(record)
                        }
                    }
                    .padding(15)
                }
                .background(JustSnapTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .overlay {
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(JustSnapTheme.border, lineWidth: 1)
                }
                .padding(16)
            }
            .background(JustSnapTheme.subtleSurface)
        } else {
            ContentUnavailableView(JustSnapStrings.historyEmptyTitle, systemImage: JustSnapIcon.history.rawValue)
        }
    }

    private func historyDetailHeader(_ record: HistoryRecord) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.operation.sourceMarkdown ?? JustSnapStrings.failed)
                    .font(.title2.bold())
                    .lineLimit(2)
                Text("\(record.operation.selection.providerID) · \(record.operation.selection.modelID)")
                    .foregroundStyle(JustSnapTheme.secondaryText)
            }
            Spacer()
            HStack(spacing: 0) {
            Button { callbacks.onRetryRecord(record.id) } label: {
                Group {
                    if historyRetry.isRunning && historyRetry.recordID == record.id {
                        ProgressView().controlSize(.small)
                    } else {
                        JustSnapIcon.retry.image
                    }
                }
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(!HistoryRetryAvailability.isAvailable(
                for: record,
                allowsStart: historyRetry.allowsStart,
                isRunning: historyRetry.isRunning,
                hasLoadedImage: selectedImage != nil && imageRecordID == record.id
            ))
            .help(JustSnapStrings.retry)
            .accessibilityLabel(JustSnapStrings.retry)
            .accessibilityIdentifier("history-retry")
            Button {
                callbacks.onSetPinned(record.id, !record.isPinned)
            } label: {
                (record.isPinned ? JustSnapIcon.pinned : JustSnapIcon.pin).image
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            Button(role: .destructive) { pendingDeletion = record } label: {
                JustSnapIcon.delete.image
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(record.operation.status.isActive || historyRetry.preventsDiscard)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .frame(minHeight: 46)
    }

    private func historyRetryContent(_ record: HistoryRecord) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            switch historyRetry.slot.attempt {
            case .neverStarted, .preparing:
                Text(JustSnapStrings.preparing)
            case .streaming:
                Text(JustSnapStrings.streaming)
                historyResult(record, source: historyRetry.slot.sourceDelta,
                              translation: historyRetry.slot.translationDelta, segments: historyRetry.slot.segments)
            case .succeeded:
                historyResult(record, source: historyRetry.slot.committedResult?.sourceMarkdown,
                              translation: historyRetry.slot.committedResult?.translationMarkdown,
                              segments: historyRetry.slot.committedResult?.segments)
            case let .failed(code):
                Text(code == "history_screenshot_unavailable" ? JustSnapStrings.historyScreenshotUnavailable
                     : JustSnapStrings.failureMessage(code: code))
                    .foregroundStyle(JustSnapTheme.destructive)
            case .canceled:
                Text(JustSnapStrings.canceled)
            case .resultPersistenceFailed:
                historyResult(record, source: historyRetry.slot.unsavedResult?.sourceMarkdown,
                              translation: historyRetry.slot.unsavedResult?.translationMarkdown,
                              segments: historyRetry.slot.unsavedResult?.segments)
                Text(historyRetry.slot.persistenceFailureCode.map(JustSnapStrings.failureMessage(code:))
                     ?? JustSnapStrings.persistenceFailed).foregroundStyle(JustSnapTheme.destructive)
                Button(JustSnapStrings.retrySave, action: callbacks.onRetryHistorySave)
                    .disabled(historyRetry.isRunning)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var filteredRecords: [HistoryRecord] {
        records.filter { record in
            let kindMatches = kind == .all
                || (kind == .extract && record.operation.kind == .extract)
                || (kind == .translate && record.operation.kind == .translate)
            return kindMatches && (!pinnedOnly || record.isPinned)
                && (historyProviderID == nil || record.operation.selection.providerID == historyProviderID)
                && HistoryLocalSearch.matches(record, query: searchText)
        }
    }

    private var selectedRecord: HistoryRecord? {
        filteredRecords.first { $0.id == selectedRecordID } ?? filteredRecords.first
    }

    private func sidebarHeading(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(JustSnapTheme.secondaryText)
            .padding(.horizontal, 9)
            .padding(.top, 14)
    }

    private func navButton(_ title: String, icon: JustSnapIcon, count: Int? = nil, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Label(title, systemImage: icon.rawValue)
                Spacer(minLength: 0)
                if let count {
                    Text(count, format: .number)
                        .font(.caption)
                        .foregroundStyle(JustSnapTheme.secondaryText)
                }
            }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .frame(height: 34)
                .contentShape(Rectangle())
                .background(selected ? JustSnapTheme.accent.opacity(0.15) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: JustSnapUIConstants.compactCornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func historyRow(_ record: HistoryRecord) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(record.operation.sourceMarkdown ?? JustSnapStrings.failed)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(JustSnapTheme.historyTitle)
                .lineLimit(1)
                .padding(.bottom, 6)
            Text(historySummary(record))
                .font(.system(size: 11))
                .foregroundStyle(JustSnapTheme.historySummary)
                .lineLimit(1)
                .padding(.bottom, 7)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    historyRowTags(record).fixedSize()
                    Spacer(minLength: 10)
                    historyRowDate(record).fixedSize()
                }
                VStack(alignment: .leading, spacing: 5) {
                    historyRowTags(record)
                    historyRowDate(record).frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .font(.system(size: 10))
        }
    }

    private func historySummary(_ record: HistoryRecord) -> String {
        if let translation = record.operation.translationMarkdown, !translation.isEmpty { return translation }
        if let source = record.operation.sourceMarkdown, !source.isEmpty { return source }
        return historyStatus(record.operation.status).text
    }

    private func historyRowTags(_ record: HistoryRecord) -> some View {
        HStack(spacing: 7) {
            Text(record.operation.kind == .extract ? JustSnapStrings.historyExtract : JustSnapStrings.translate)
                .foregroundStyle(JustSnapTheme.historyType)
            Text(historyStatus(record.operation.status).text)
                .foregroundStyle(historyStatus(record.operation.status).color)
        }
    }

    private func historyRowDate(_ record: HistoryRecord) -> some View {
        Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
            .foregroundStyle(JustSnapTheme.historyDate)
            .multilineTextAlignment(.trailing)
    }

    private func historyStatus(_ status: OperationStatus) -> (text: String, color: Color) {
        switch status {
        case .succeeded: (JustSnapStrings.menuStatusSucceeded, JustSnapTheme.historySucceeded)
        case .canceled: (JustSnapStrings.menuStatusCanceled, JustSnapTheme.historyCanceled)
        case .interrupted: (JustSnapStrings.historyInterrupted, JustSnapTheme.historyFailed)
        case .failed, .resultPersistenceFailed: (JustSnapStrings.menuStatusFailed, JustSnapTheme.historyFailed)
        case .preparing, .uploading, .streaming: (JustSnapStrings.menuStatusActive, JustSnapTheme.secondaryText)
        }
    }

    @ViewBuilder
    private func screenshot(_ record: HistoryRecord) -> some View {
        if let selectedImage, imageRecordID == record.id {
            Button { previewImage = HistoryPreviewImage(image: selectedImage) } label: {
                Image(nsImage: selectedImage).resizable().scaledToFit()
                    .frame(maxHeight: 100)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(HistoryImageButtonStyle())
            .help(JustSnapStrings.historyViewOriginal)
            .accessibilityLabel(JustSnapStrings.historyViewOriginal)
            .accessibilityIdentifier("history-image-preview")
        } else {
            ZStack {
                Color.clear
                if selectedImageLoadFailed && imageRecordID == record.id {
                    Label(JustSnapStrings.historyScreenshotUnavailable, systemImage: JustSnapIcon.warning.rawValue)
                }
            }
                .foregroundStyle(JustSnapTheme.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 100)
                .background(JustSnapTheme.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: JustSnapUIConstants.cardCornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: JustSnapUIConstants.cardCornerRadius)
                        .strokeBorder(JustSnapTheme.historyImageBorder, lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    private func historyResult(_ record: HistoryRecord, source: String?, translation: String?, segments: [TranslationSegment]?) -> some View {
        if record.operation.kind == .translate {
            BilingualResultView(source: source ?? "", translation: translation ?? "", segments: segments)
                .id(record.id)
                .padding(.horizontal, -15)
        } else {
            resultSection(JustSnapStrings.historyOriginal, text: source)
        }
    }

    private func resultSection(_ title: String, text: String?) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(title).font(.system(size: 15, weight: .semibold))
                Spacer()
                ResultCopyButton(text: text ?? "") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString($0, forType: .string)
                }
            }
            Text(text ?? JustSnapStrings.historyUnavailable).textSelection(.enabled)
        }
    }

    private func metrics(_ record: HistoryRecord) -> some View {
        HStack(spacing: 24) {
            metric(JustSnapStrings.historyFirstTextLatency, value: latency(record.metrics.firstTextLatencyMilliseconds))
            metric(JustSnapStrings.historyTotalLatency, value: latency(record.metrics.totalLatencyMilliseconds))
            metric(
                JustSnapStrings.historyTokenUsage,
                value: record.metrics.usage.map {
                    String(
                        format: JustSnapStrings.historyTokenUsageFormat,
                        $0.inputTokens,
                        $0.outputTokens,
                        $0.totalTokens
                    )
                } ?? JustSnapStrings.historyUnavailable
            )
        }
        .padding(12)
        .background(JustSnapTheme.subtleSurface)
        .clipShape(RoundedRectangle(cornerRadius: JustSnapUIConstants.compactCornerRadius))
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(JustSnapTheme.secondaryText)
            Text(value).fontWeight(.medium)
        }
    }

    private func latency(_ milliseconds: Int?) -> String {
        milliseconds.map {
            Measurement(value: Double($0) / 1_000, unit: UnitDuration.seconds)
                .formatted(
                    .measurement(
                        width: .abbreviated,
                        usage: .asProvided,
                        numberFormatStyle: .number.precision(.fractionLength(2))
                    )
                )
        }
            ?? JustSnapStrings.historyUnavailable
    }

    private func reconcileHistorySelection() {
        if !filteredRecords.contains(where: { $0.id == selectedRecordID }) {
            selectedRecordID = filteredRecords.first?.id
        }
    }

    private var retentionShorteningTitle: String {
        String(
            format: JustSnapStrings.historyRetentionShorteningConfirm,
            settings.retentionShorteningRecordCount ?? 0
        )
    }
}

/// Whether history detail offers Retry: an image record needs its original loaded first; a Pasted Text record
/// reruns on its saved text (clipboard-paste::REQ-008/AC-06).
enum HistoryRetryAvailability {
    static func isAvailable(for record: HistoryRecord, allowsStart: Bool, isRunning: Bool, hasLoadedImage: Bool) -> Bool {
        allowsStart && !isRunning && !record.operation.status.isActive
            && (record.operation.pastedText != nil || hasLoadedImage)
            // Text Extraction never runs on Pasted Text; such a record from an earlier version stays as it is
            // (clipboard-paste::REQ-007/AC-08).
            && !(record.operation.pastedText != nil && record.operation.kind == .extract)
    }
}

/// The history list's local search over a record's results and its Pasted Text (clipboard-paste::REQ-008/AC-04).
enum HistoryLocalSearch {
    static func matches(_ record: HistoryRecord, query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return true }
        return [record.operation.sourceMarkdown, record.operation.translationMarkdown, record.operation.pastedText]
            .compactMap { $0 }.joined(separator: "\n").lowercased().contains(query)
    }
}

/// A Pasted Text record's text where an image record shows its original: read-only, scrollable and
/// selectable, with only Copy and Select All in its menu (clipboard-paste::REQ-008/AC-03, v1-core::REQ-010/AC-11).
struct HistoryPastedTextView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.horizontalScrollElasticity = .none
        let textView = ResultBoxTextView()
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.textColor = .labelColor
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? ResultBoxTextView, textView.string != text else { return }
        textView.string = text
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.scrollToBeginningOfDocument(nil)
    }
}
