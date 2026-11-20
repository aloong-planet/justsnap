import SwiftUI
import JustSnapCore

public struct OnboardingView: View {
    private let snapshot: OnboardingSnapshot
    private let onConfigurePermission: () -> Void
    private let onConfigureProvider: () -> Void
    private let onViewPrivacy: () -> Void
    private let onStart: () -> Void
    private let onFinishLater: () -> Void

    public init(
        snapshot: OnboardingSnapshot,
        onConfigurePermission: @escaping () -> Void,
        onConfigureProvider: @escaping () -> Void,
        onViewPrivacy: @escaping () -> Void,
        onStart: @escaping () -> Void,
        onFinishLater: @escaping () -> Void
    ) {
        self.snapshot = snapshot
        self.onConfigurePermission = onConfigurePermission
        self.onConfigureProvider = onConfigureProvider
        self.onViewPrivacy = onViewPrivacy
        self.onStart = onStart
        self.onFinishLater = onFinishLater
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    OnboardingBrandMark()
                        .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(JustSnapTheme.onAccent)
                        .frame(width: 26, height: 26)
                        .frame(width: 44, height: 44)
                        .background(JustSnapTheme.accent, in: RoundedRectangle(cornerRadius: 11))
                        .frame(width: 52)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(JustSnapStrings.onboardingIntroTitle).font(.system(size: 25, weight: .bold))
                        Text(JustSnapStrings.onboardingIntroDescription)
                            .font(.system(size: 13))
                            .foregroundStyle(JustSnapTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.bottom, 12)
                VStack(spacing: 10) {
                    permissionRow
                    providerRow
                    privacyRow
                }
                readinessGate
                HStack(spacing: 14) {
                    Text(JustSnapStrings.onboardingPrivacyNote)
                        .font(.system(size: 11))
                        .foregroundStyle(JustSnapTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    HStack(spacing: 8) {
                        Button(JustSnapStrings.finishLater, action: onFinishLater)
                            .buttonStyle(.borderless)
                        Button(JustSnapStrings.startUsing, action: onStart)
                            .buttonStyle(.borderedProminent)
                            .disabled(!snapshot.canStart)
                    }
                    .fixedSize()
                }
            }
            .frame(maxWidth: 760)
            .padding(.horizontal, 32)
            .padding(.top, 26)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity)
        }
        .background(JustSnapTheme.window)
        .frame(width: OnboardingMetrics.width)
        .frame(minHeight: OnboardingMetrics.minimumHeight)
    }

    private var permissionRow: some View {
        readinessRow(
            icon: .permission,
            title: JustSnapStrings.permissionTitle,
            detail: permissionStatus,
            description: JustSnapStrings.onboardingPermissionDescription,
            complete: snapshot.permission == .ready,
            actionTitle: snapshot.permission == .ready
                ? JustSnapStrings.modify
                : JustSnapStrings.configure,
            action: onConfigurePermission
        )
    }

    private var providerRow: some View {
        readinessRow(
            icon: .provider,
            title: JustSnapStrings.providerTitle,
            detail: providerDetail,
            description: JustSnapStrings.onboardingProviderDescription,
            complete: providerIsReady,
            actionTitle: JustSnapStrings.onboardingProviderAction,
            action: onConfigureProvider
        )
    }

    private var privacyRow: some View {
        readinessRow(
            icon: .info,
            title: JustSnapStrings.privacyTitle,
            detail: JustSnapStrings.onboardingImportant,
            description: JustSnapStrings.onboardingPrivacyDescription,
            complete: true,
            actionTitle: JustSnapStrings.viewDetails,
            action: onViewPrivacy
        )
    }

    private func readinessRow(
        icon: JustSnapIcon,
        title: String,
        detail: String,
        description: String,
        complete: Bool,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 13) {
            icon.image
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(JustSnapTheme.accent)
                .frame(width: 40, height: 40)
                .background(JustSnapTheme.accentSoft, in: RoundedRectangle(cornerRadius: 9))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(JustSnapTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 3)
                Text(detail)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(complete ? JustSnapTheme.success : JustSnapTheme.warning)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(complete ? JustSnapTheme.successSoft : JustSnapTheme.warningSoft,
                                in: RoundedRectangle(cornerRadius: 9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Button(actionTitle, action: action)
                .buttonStyle(SetupActionButtonStyle(horizontalPadding: 12))
                .fixedSize()
        }
        .padding(14)
        .frame(minHeight: OnboardingMetrics.rowMinimumHeight)
        .background(JustSnapTheme.surface)
        .clipShape(
            RoundedRectangle(cornerRadius: OnboardingMetrics.rowCornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OnboardingMetrics.rowCornerRadius, style: .continuous)
                .stroke(JustSnapTheme.border, lineWidth: 1)
        }
    }

    private var readinessGate: some View {
        HStack(alignment: .top, spacing: 10) {
            (snapshot.canStart ? JustSnapIcon.downloaded : JustSnapIcon.warning).image
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(gateTitle).font(.system(size: 11, weight: .semibold))
                Text(gateDetail + " " + JustSnapStrings.onboardingLaterNote)
                    .font(.system(size: 10))
                    .foregroundStyle(JustSnapTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .foregroundStyle(snapshot.canStart ? JustSnapTheme.success : JustSnapTheme.warning)
        .background(snapshot.canStart ? JustSnapTheme.successSoft : JustSnapTheme.warningSoft,
                    in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .stroke((snapshot.canStart ? JustSnapTheme.success : JustSnapTheme.warning).opacity(0.28)))
    }

    private var gateTitle: String {
        if snapshot.canStart { return JustSnapStrings.onboardingReadyTitle }
        if snapshot.permission == .ready { return JustSnapStrings.providerBlocker }
        if providerIsReady { return JustSnapStrings.permissionBlocker }
        return JustSnapStrings.onboardingBothMissingTitle
    }

    private var gateDetail: String {
        if snapshot.canStart { return JustSnapStrings.onboardingReadyDetail }
        if snapshot.permission == .ready { return JustSnapStrings.onboardingProviderDescription }
        if providerIsReady { return permissionDetail }
        return JustSnapStrings.onboardingBothMissingDetail
    }

    private var permissionDetail: String {
        switch snapshot.permission {
        case .notRequested: JustSnapStrings.permissionRecoveryInitial
        case .unavailable: JustSnapStrings.permissionRecoveryDenied
        case .restartRequired: JustSnapStrings.permissionRecoveryRestart
        case .ready: JustSnapStrings.permissionReady
        }
    }

    private var permissionStatus: String {
        switch snapshot.permission {
        case .notRequested, .unavailable: JustSnapStrings.onboardingPermissionMissing
        case .restartRequired: JustSnapStrings.onboardingPermissionRestart
        case .ready: JustSnapStrings.onboardingPermissionReady
        }
    }

    private var providerDetail: String {
        switch snapshot.provider {
        case .missing:
            JustSnapStrings.notConfigured
        case let .pendingModel(provider):
            "\(JustSnapStrings.providerName(provider)) · \(JustSnapStrings.modelPending)"
        case let .ready(provider, modelID):
            "\(JustSnapStrings.providerName(provider)) · \(modelID)"
        }
    }

    private var providerIsReady: Bool {
        if case .ready = snapshot.provider { true } else { false }
    }

}
