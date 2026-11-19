import SwiftUI

public struct StoragePrivacyDetailView: View {
    private let onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(JustSnapStrings.privacyDetailsTitle).font(.title2.bold())
                Spacer()
                Button(action: onClose) {
                    JustSnapIcon.close.image
                }
                .buttonStyle(.plain)
                .accessibilityLabel(JustSnapStrings.close)
            }
            .padding(24)
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                section(
                    icon: .provider,
                    title: JustSnapStrings.privacyUploadTitle,
                    body: JustSnapStrings.privacyUploadBody
                )
                Divider()
                section(
                    icon: .folder,
                    title: JustSnapStrings.privacyStorageTitle,
                    body: JustSnapStrings.privacyStorageBody
                )
                Divider()
                section(
                    icon: .history,
                    title: JustSnapStrings.privacyRetentionTitle,
                    body: JustSnapStrings.privacyRetentionBody
                )
                Divider()
                section(
                    icon: .info,
                    title: JustSnapStrings.privacyBackupTitle,
                    body: JustSnapStrings.privacyBackupBody
                )
            }
            .padding(.horizontal, 24)
            Spacer(minLength: 0)
            Divider()
            HStack {
                Spacer()
                Button(JustSnapStrings.close, action: onClose)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(18)
        }
        .background(JustSnapTheme.window)
        .clipShape(
            RoundedRectangle(
                cornerRadius: JustSnapUIConstants.attachedSheetCornerRadius,
                style: .continuous
            )
        )
        .frame(width: 620, height: 520)
        .permitsApplicationTerminationWhilePresented()
    }

    private func section(
        icon: JustSnapIcon,
        title: String,
        body: String
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            icon.image
                .foregroundStyle(JustSnapTheme.accent)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(body)
                    .foregroundStyle(JustSnapTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 18)
    }
}
