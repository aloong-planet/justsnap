import AppKit
import SwiftUI
import JustSnapCore

public enum ManagementCenterDestination: Equatable, Sendable {
    case history
    case providerSettings
    case settings
}

public struct MenuRecentItem: Identifiable, Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case active
        case succeeded
        case failed
        case canceled
    }

    public let id: String
    public let title: String
    public let detail: String
    public let status: Status
    /// The original image's file; `nil` for a Pasted Text record, which has none (clipboard-paste::REQ-008/AC-02).
    public let screenshotURL: URL?

    public init(
        id: String,
        title: String,
        detail: String,
        status: Status = .succeeded,
        screenshotURL: URL? = URL(fileURLWithPath: "/dev/null")
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.status = status
        self.screenshotURL = screenshotURL
    }

    public init(record: HistoryRecord, now: Date = Date()) {
        id = record.id.uuidString
        title = Self.title(for: record)
        detail = "\(Self.operationLabel(for: record.operation.kind)) · \(Self.relativeTime(from: record.createdAt, to: now))"
        status = Self.status(for: record.operation.status)
        screenshotURL = record.operation.screenshot.map { URL(fileURLWithPath: $0.path) }
    }

    /// What the recent row's thumbnail slot shows (clipboard-paste::REQ-008/AC-02).
    enum Thumbnail {
        case image(NSImage)
        case pastedText
        case missingScreenshot
    }

    func thumbnail(loading load: (URL) -> NSImage? = { NSImage(contentsOf: $0) }) -> Thumbnail {
        guard let screenshotURL else {
            return .pastedText
        }
        return load(screenshotURL).map(Thumbnail.image) ?? .missingScreenshot
    }

    private static func title(for record: HistoryRecord) -> String {
        if let source = record.operation.sourceMarkdown,
           let firstLine = source.split(whereSeparator: \.isNewline).first,
           !firstLine.isEmpty {
            let line = String(firstLine).trimmingCharacters(in: .whitespaces)
            let title = line.drop(while: { $0 == "#" })
                .trimmingCharacters(in: .whitespaces)
            if !title.isEmpty {
                return title
            }
        }
        if record.operation.status == .failed {
            return JustSnapStrings.menuProviderRequestFailed
        }
        return operationLabel(for: record.operation.kind)
    }

    private static func operationLabel(for kind: PersistedOperationKind) -> String {
        switch kind {
        case .extract: JustSnapStrings.extract
        case .translate: JustSnapStrings.translate
        }
    }

    private static func status(for status: OperationStatus) -> Status {
        switch status {
        case .preparing, .uploading, .streaming: .active
        case .succeeded: .succeeded
        case .failed, .interrupted, .resultPersistenceFailed: .failed
        case .canceled: .canceled
        }
    }

    private static func relativeTime(from date: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 {
            return JustSnapStrings.menuTimeNow
        }
        if seconds < 3_600 {
            return String(format: JustSnapStrings.menuTimeMinutesFormat, seconds / 60)
        }
        if seconds < 86_400 {
            return String(format: JustSnapStrings.menuTimeHoursFormat, seconds / 3_600)
        }
        return String(format: JustSnapStrings.menuTimeDaysFormat, seconds / 86_400)
    }
}

public struct MenuProviderPresentation: Equatable, Sendable {
    public let providerName: String?
    public let isAvailable: Bool

    public init(readiness: ProviderReadiness) {
        switch readiness {
        case .missing:
            providerName = nil
            isAvailable = false
        case let .pendingModel(provider):
            providerName = JustSnapStrings.providerName(provider)
            isAvailable = false
        case let .ready(provider, _):
            providerName = JustSnapStrings.providerName(provider)
            isAvailable = true
        }
    }

    var label: String {
        guard let providerName else {
            return JustSnapStrings.menuSetupRequired
        }
        return isAvailable
            ? String(format: JustSnapStrings.menuProviderAvailableFormat, providerName)
            : String(format: JustSnapStrings.menuProviderNeedsModelFormat, providerName)
    }
}

public enum MenuBarPanelMetrics {
    public static let width: CGFloat = 300
    public static let arrowSize = CGSize(width: 8, height: 4)
    public static let arrowEdgeInset: CGFloat = 12
    public static let screenEdgeInset: CGFloat = 4
    public static let outerCornerRadius: CGFloat = 13
    public static let captureButtonHeight: CGFloat = 36
    public static let recentThumbnailSize = CGSize(width: 58, height: 42)
}

enum MenuBarPanelActionRole: CaseIterable {
    case primary
    case row
    case footer

    func backgroundOpacity(isHovering: Bool) -> Double {
        switch self {
        case .primary:
            isHovering ? 0.46 : 0
        case .row, .footer:
            isHovering ? 1 : 0
        }
    }
}

struct MenuBarPanelActionButton<Label: View>: View {
    private let role: MenuBarPanelActionRole
    private let action: () -> Void
    private let label: () -> Label
    @State private var isHovering = false

    init(
        role: MenuBarPanelActionRole,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.role = role
        self.action = action
        self.label = label
    }

    var body: some View {
        Button(action: action) {
            label()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(background)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private var background: some View {
        switch role {
        case .primary:
            JustSnapTheme.subtleSurface.opacity(
                role.backgroundOpacity(isHovering: isHovering)
            )
        case .row, .footer:
            JustSnapTheme.subtleSurface.opacity(
                role.backgroundOpacity(isHovering: isHovering)
            )
        }
    }
}

public struct MenuBarPanelView: View {
    private let recentItems: [MenuRecentItem]
    private let provider: ProviderReadiness
    private let updateState: UpdateLifecycleState
    private let captureShortcut: String
    /// Nil when the paste shortcut is unset; the button then shows no shortcut.
    private let pasteShortcut: String?
    private let targetLanguageCode: String
    private let targetLanguages: [TargetLanguageOption]
    private let onCapture: () -> Void
    private let onPaste: () -> Void
    private let onOpenRecent: (String) -> Void
    private let onNavigate: (ManagementCenterDestination) -> Void
    private let onCheckUpdates: () -> Void
    private let onDownloadUpdate: () -> Void
    private let onOpenUpdateInformation: (URL) -> Void
    private let onTargetLanguageChange: (String) -> Void
    @State private var isLanguageListPresented = false

    public init(
        recentItems: [MenuRecentItem],
        provider: ProviderReadiness = .missing,
        updateState: UpdateLifecycleState = .idle,
        captureShortcut: String = "⌥⇧S",
        pasteShortcut: String? = "⌥⇧V",
        targetLanguageCode: String = "zh-Hans",
        targetLanguages: [TargetLanguageOption] = [],
        onCapture: @escaping () -> Void,
        onPaste: @escaping () -> Void = {},
        onOpenRecent: @escaping (String) -> Void,
        onNavigate: @escaping (ManagementCenterDestination) -> Void,
        onCheckUpdates: @escaping () -> Void,
        onDownloadUpdate: @escaping () -> Void = {},
        onOpenUpdateInformation: @escaping (URL) -> Void = { _ in },
        onTargetLanguageChange: @escaping (String) -> Void = { _ in }
    ) {
        self.recentItems = recentItems
        self.provider = provider
        self.updateState = updateState
        self.captureShortcut = captureShortcut
        self.pasteShortcut = pasteShortcut
        self.onCapture = onCapture
        self.onPaste = onPaste
        self.onOpenRecent = onOpenRecent
        self.onNavigate = onNavigate
        self.onCheckUpdates = onCheckUpdates
        self.onDownloadUpdate = onDownloadUpdate
        self.onOpenUpdateInformation = onOpenUpdateInformation
        self.targetLanguageCode = targetLanguageCode
        self.targetLanguages = targetLanguages
        self.onTargetLanguageChange = onTargetLanguageChange
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(JustSnapStrings.appName)
                    .font(.title3.bold())
                Spacer()
                providerBadge
            }
            .padding(.horizontal, 14)
            .frame(height: 50)

            // Capture and Paste share the row equally (clipboard-paste::REQ-001/AC-01).
            HStack(spacing: 8) {
                primaryAction(
                    JustSnapStrings.menuCapture,
                    icon: .capture,
                    shortcut: captureShortcut,
                    action: onCapture
                )
                primaryAction(
                    JustSnapStrings.menuPaste,
                    icon: .paste,
                    shortcut: pasteShortcut,
                    action: onPaste
                )
            }
            .padding(.horizontal, 10)
            targetLanguageRow
            if updateState.showsMenuNotice {
                updateNotice
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(JustSnapStrings.menuRecent)
                    .font(.caption.bold())
                    .foregroundStyle(JustSnapTheme.secondaryText)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                if recentItems.isEmpty {
                    Text(JustSnapStrings.noRecentItems)
                        .font(.callout)
                        .foregroundStyle(JustSnapTheme.secondaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                } else {
                ForEach(recentItems.prefix(5)) { item in
                        MenuBarPanelActionButton(
                            role: .row,
                            action: { onOpenRecent(item.id) }
                        ) {
                            HStack(spacing: 10) {
                                recentThumbnail(for: item)
                                    .frame(
                                        width: MenuBarPanelMetrics.recentThumbnailSize.width,
                                        height: MenuBarPanelMetrics.recentThumbnailSize.height
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .stroke(JustSnapTheme.border)
                                    )
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title)
                                        .font(.callout.weight(.semibold))
                                        .lineLimit(1)
                                    Text(item.detail)
                                        .font(.caption)
                                        .foregroundStyle(JustSnapTheme.secondaryText)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 4)
                                statusBadge(for: item.status)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .frame(height: 54)
                            .contentShape(Rectangle())
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(.horizontal, 6)
                    }
                }
            }
            .padding(.bottom, 8)
            Divider()
            HStack(spacing: 0) {
                footerButton(JustSnapStrings.historyProviderSettings) { onNavigate(.providerSettings) }
                Divider().frame(height: 38)
                footerButton(JustSnapStrings.menuGeneralSettings) { onNavigate(.settings) }
            }
        }
        .background(JustSnapTheme.window)
        .clipShape(RoundedRectangle(cornerRadius: MenuBarPanelMetrics.outerCornerRadius))
        .frame(width: MenuBarPanelMetrics.width)
    }

    /// The remembered target language, set here as in the toolbar and the paste box (v1-core::REQ-017).
    private var targetLanguageRow: some View {
        MenuBarPanelActionButton(role: .row) {
            isLanguageListPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                Text(JustSnapStrings.menuTranslateTo)
                    .font(.callout)
                Spacer(minLength: 8)
                Text(JustSnapLocalization.localizedLanguageName(for: targetLanguageCode))
                    .font(.callout)
                    .foregroundStyle(JustSnapTheme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                JustSnapIcon.chevronDown.image
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(JustSnapTheme.secondaryText)
            }
            .padding(.horizontal, 8)
            .frame(height: 32)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .popover(isPresented: $isLanguageListPresented, arrowEdge: .bottom) {
            TargetLanguageList(
                options: targetLanguages,
                selectedCode: targetLanguageCode
            ) { code in
                onTargetLanguageChange(code)
                isLanguageListPresented = false
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 6)
    }

    private var providerBadge: some View {
        let presentation = MenuProviderPresentation(readiness: provider)
        return Text(presentation.label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(presentation.isAvailable ? Color.green : JustSnapTheme.secondaryText)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                (presentation.isAvailable ? Color.green : JustSnapTheme.secondaryText)
                    .opacity(0.10),
                in: Capsule()
            )
    }

    @ViewBuilder
    private func recentThumbnail(for item: MenuRecentItem) -> some View {
        switch item.thumbnail() {
        case let .image(image):
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        case .pastedText:
            ZStack {
                JustSnapTheme.surface
                JustSnapIcon.pastedText.image
                    .foregroundStyle(JustSnapTheme.secondaryText)
            }
        case .missingScreenshot:
            ZStack {
                JustSnapTheme.surface
                JustSnapIcon.capture.image
                    .foregroundStyle(JustSnapTheme.secondaryText)
            }
        }
    }

    private func statusBadge(for status: MenuRecentItem.Status) -> some View {
        let presentation: (String, Color) = switch status {
        case .active: (JustSnapStrings.menuStatusActive, JustSnapTheme.accent)
        case .succeeded: (JustSnapStrings.menuStatusSucceeded, .green)
        case .failed: (JustSnapStrings.menuStatusFailed, .red)
        case .canceled: (JustSnapStrings.menuStatusCanceled, JustSnapTheme.secondaryText)
        }
        return Text(presentation.0)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(presentation.1)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(presentation.1.opacity(0.10), in: Capsule())
    }

    private var updateNotice: some View {
        HStack(spacing: 9) {
            updateNoticeIcon
                .frame(width: 28, height: 28)
                .background(JustSnapTheme.surface, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(updateState.menuTitle).font(.caption.bold()).lineLimit(1)
                Text(updateState.menuDetail)
                    .font(.caption2)
                    .foregroundStyle(JustSnapTheme.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            switch updateState {
            case .available:
                Button(JustSnapStrings.updateDownload, action: onDownloadUpdate)
                    .buttonStyle(.bordered)
            case .readyToInstall:
                Button(JustSnapStrings.updateView) { onNavigate(.settings) }
                    .buttonStyle(.bordered)
            default:
                EmptyView()
            }
        }
        .padding(9)
        .background(JustSnapTheme.accent.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(JustSnapTheme.border))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 10)
        .padding(.top, 6)
    }

    private func primaryAction(
        _ title: String,
        icon: JustSnapIcon,
        shortcut: String?,
        action: @escaping () -> Void
    ) -> some View {
        MenuBarPanelActionButton(role: .primary, action: action) {
            // Half-width buttons: this padding and gap leave room for the English "Capture" with its shortcut.
            HStack(spacing: 4) {
                Label(title, systemImage: icon.rawValue)
                    .font(.headline)
                    .foregroundStyle(JustSnapTheme.primaryText)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(JustSnapTheme.secondaryText)
                        .fixedSize()
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: MenuBarPanelMetrics.captureButtonHeight)
        .background(JustSnapTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(JustSnapTheme.border.opacity(0.55), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: JustSnapTheme.shadow.opacity(0.10), radius: 3.5, y: 2)
    }

    @ViewBuilder
    private var updateNoticeIcon: some View {
        switch updateState {
        case .downloading:
            ProgressView().controlSize(.small)
        case .readyToInstall:
            JustSnapIcon.downloaded.image.foregroundStyle(JustSnapTheme.accent)
        default:
            JustSnapIcon.update.image.foregroundStyle(JustSnapTheme.accent)
        }
    }

    private func footerButton(_ title: String, action: @escaping () -> Void) -> some View {
        MenuBarPanelActionButton(role: .footer, action: action) {
            Text(title)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .frame(height: 42)
        }
    }
}

private extension UpdateLifecycleState {
    var showsMenuNotice: Bool {
        showsAttentionIndicator
    }

    var menuTitle: String {
        switch self {
        case let .available(version):
            String(format: JustSnapStrings.updateAvailableTitleFormat, version.displayVersion)
        case let .downloading(version, _, _):
            String(format: JustSnapStrings.updateDownloadingTitleFormat, version.displayVersion)
        case let .readyToInstall(version):
            String(format: JustSnapStrings.updateReadyTitleFormat, version.displayVersion)
        default: ""
        }
    }

    var menuDetail: String {
        switch self {
        case .available: JustSnapStrings.updateAvailableMenuDetail
        case .downloading: JustSnapStrings.updateDownloadingMenuDetail
        case .readyToInstall: JustSnapStrings.updateReadyMenuDetail
        default: ""
        }
    }
}
