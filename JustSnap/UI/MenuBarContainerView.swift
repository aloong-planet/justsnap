import SwiftUI
import JustSnapCore

enum MenuCaptureActionHandler {
    static func perform(
        route: MenuCaptureRoute,
        performCapture: () -> Void
    ) {
        switch route {
        case .configureProvider, .recoverPermission, .capture:
            performCapture()
        }
    }
}

public struct MenuBarCallbacks {
    public let onCapture: () -> Void
    public let onPaste: () -> Void
    public let onOpenRecent: (String) -> Void
    public let onNavigate: (ManagementCenterDestination) -> Void
    public let onCheckUpdates: () -> Void
    public let onDownloadUpdate: () -> Void
    public let onOpenUpdateInformation: (URL) -> Void
    public let onTargetLanguageChange: (String) -> Void

    public init(
        onCapture: @escaping () -> Void,
        onPaste: @escaping () -> Void = {},
        onOpenRecent: @escaping (String) -> Void,
        onNavigate: @escaping (ManagementCenterDestination) -> Void,
        onCheckUpdates: @escaping () -> Void,
        onDownloadUpdate: @escaping () -> Void = {},
        onOpenUpdateInformation: @escaping (URL) -> Void = { _ in },
        onTargetLanguageChange: @escaping (String) -> Void = { _ in }
    ) {
        self.onCapture = onCapture
        self.onPaste = onPaste
        self.onOpenRecent = onOpenRecent
        self.onNavigate = onNavigate
        self.onCheckUpdates = onCheckUpdates
        self.onDownloadUpdate = onDownloadUpdate
        self.onOpenUpdateInformation = onOpenUpdateInformation
        self.onTargetLanguageChange = onTargetLanguageChange
    }
}

public struct MenuBarContainerView: View {
    private let recentItems: [MenuRecentItem]
    private let permission: ScreenCapturePermissionReadiness
    private let provider: ProviderReadiness
    private let updateState: UpdateLifecycleState
    private let captureShortcut: String
    private let pasteShortcut: String?
    /// What the panel's translation language row shows (v1-core::REQ-017).
    public let targetLanguageCode: String
    private let targetLanguages: [TargetLanguageOption]
    public let callbacks: MenuBarCallbacks

    public init(
        recentItems: [MenuRecentItem],
        permission: ScreenCapturePermissionReadiness,
        provider: ProviderReadiness,
        updateState: UpdateLifecycleState = .idle,
        captureShortcut: String = "⌥⇧S",
        pasteShortcut: String? = "⌥⇧V",
        targetLanguageCode: String = "zh-Hans",
        targetLanguages: [TargetLanguageOption] = [],
        callbacks: MenuBarCallbacks
    ) {
        self.recentItems = recentItems
        self.permission = permission
        self.provider = provider
        self.updateState = updateState
        self.captureShortcut = captureShortcut
        self.pasteShortcut = pasteShortcut
        self.targetLanguageCode = targetLanguageCode
        self.targetLanguages = targetLanguages
        self.callbacks = callbacks
    }

    public var body: some View {
        MenuBarPanelView(
            recentItems: recentItems,
            provider: provider,
            updateState: updateState,
            captureShortcut: captureShortcut,
            pasteShortcut: pasteShortcut,
            targetLanguageCode: targetLanguageCode,
            targetLanguages: targetLanguages,
            onCapture: routeCapture,
            onPaste: callbacks.onPaste,
            onOpenRecent: callbacks.onOpenRecent,
            onNavigate: callbacks.onNavigate,
            onCheckUpdates: callbacks.onCheckUpdates,
            onDownloadUpdate: callbacks.onDownloadUpdate,
            onOpenUpdateInformation: callbacks.onOpenUpdateInformation,
            onTargetLanguageChange: callbacks.onTargetLanguageChange
        )
    }

    private func routeCapture() {
        MenuCaptureActionHandler.perform(
            route: MenuCaptureRouter.route(permission: permission, provider: provider),
            performCapture: callbacks.onCapture
        )
    }
}
