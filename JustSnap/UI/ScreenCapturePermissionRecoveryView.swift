import SwiftUI
import JustSnapCore

public struct ScreenCapturePermissionRecoveryView: View {
    private let state: ScreenCapturePermissionReadiness
    private let onPrimaryAction: () -> Void
    private let onDismiss: () -> Void

    public init(
        state: ScreenCapturePermissionReadiness,
        onPrimaryAction: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.state = state
        self.onPrimaryAction = onPrimaryAction
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.title2.bold())
                    Text(subtitle)
                        .foregroundStyle(JustSnapTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button(action: onDismiss) {
                    JustSnapIcon.close.image.frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(JustSnapStrings.close)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 17)
            Divider()
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    JustSnapIcon.permission.image
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(JustSnapTheme.accent)
                        .frame(width: 38, height: 38)
                        .background(JustSnapTheme.subtleSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(explanationTitle).font(.headline)
                        Text(explanation)
                            .font(.callout)
                            .foregroundStyle(JustSnapTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if state != .restartRequired && state != .ready {
                    VStack(alignment: .leading, spacing: 9) {
                        recoveryStep(1, JustSnapStrings.permissionRecoveryStepOne)
                        recoveryStep(2, JustSnapStrings.permissionRecoveryStepTwo)
                    }
                    .padding(12)
                    .background(JustSnapTheme.subtleSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 17)
            Divider()
            HStack {
                Text(footerNote)
                    .font(.caption)
                    .foregroundStyle(JustSnapTheme.secondaryText)
                    .frame(maxWidth: 270, alignment: .leading)
                Spacer()
                Button(JustSnapStrings.cancel, action: onDismiss)
                    .keyboardShortcut(.cancelAction)
                if state != .ready {
                    Button(primaryTitle, action: onPrimaryAction)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 20)
            .frame(height: 58)
        }
        .background(JustSnapTheme.window)
        .clipShape(
            RoundedRectangle(
                cornerRadius: PermissionRecoveryMetrics.cornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: PermissionRecoveryMetrics.cornerRadius,
                style: .continuous
            )
            .stroke(JustSnapTheme.border, lineWidth: 1)
        }
        .frame(width: PermissionRecoveryMetrics.width)
        .permitsApplicationTerminationWhilePresented()
    }

    private var title: String {
        state == .restartRequired
            ? JustSnapStrings.permissionRecoveryRestartTitle
            : JustSnapStrings.permissionRecoveryBlockedTitle
    }

    private var subtitle: String {
        state == .restartRequired
            ? JustSnapStrings.permissionRecoveryRestartSubtitle
            : JustSnapStrings.permissionRecoverySubtitle
    }

    private var explanationTitle: String {
        switch state {
        case .notRequested: JustSnapStrings.permissionRecoveryNotGrantedTitle
        case .unavailable: JustSnapStrings.permissionRecoveryRevokedTitle
        case .restartRequired: JustSnapStrings.permissionRecoveryEnabledTitle
        case .ready: JustSnapStrings.permissionReady
        }
    }

    private var explanation: String {
        switch state {
        case .notRequested: JustSnapStrings.permissionRecoveryInitial
        case .unavailable: JustSnapStrings.permissionRecoveryDenied
        case .restartRequired: JustSnapStrings.permissionRecoveryRestart
        case .ready: JustSnapStrings.permissionReady
        }
    }

    private var footerNote: String {
        state == .restartRequired
            ? JustSnapStrings.permissionRecoveryRestartNote
            : JustSnapStrings.permissionRecoveryLaterNote
    }

    private func recoveryStep(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(String(number))
                .font(.caption2.bold())
                .foregroundStyle(JustSnapTheme.accent)
                .frame(width: 20, height: 20)
                .background(JustSnapTheme.accent.opacity(0.10), in: Circle())
            Text(text)
                .font(.callout)
                .foregroundStyle(JustSnapTheme.secondaryText)
        }
    }

    private var primaryTitle: String {
        switch state {
        case .notRequested: JustSnapStrings.configure
        case .unavailable: JustSnapStrings.openSettings
        case .restartRequired: JustSnapStrings.restart
        case .ready: JustSnapStrings.done
        }
    }
}
