import SwiftUI

// `/Users/carti/Desktop/grep-design` 공용 모바일 부품.

/// 시안 `UiSettingRow.dc.html`.
struct GrepSettingRow: View {
    let label: String
    let sub: String
    let actionLabel: String?
    let actionKind: GrepButtonKind
    let isActionDisabled: Bool
    let actionAccessibilityId: String?
    let onAction: (() -> Void)?

    private let palette = LoggedInPalette.dark

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(palette.ink)
                if !sub.isEmpty {
                    Text(sub)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if let actionLabel, !actionLabel.isEmpty {
                let button = GrepUIButton(
                    actionLabel,
                    kind: actionKind,
                    size: .sm,
                    isDisabled: isActionDisabled || onAction == nil
                ) {
                    onAction?()
                }
                if let actionAccessibilityId {
                    button.accessibilityIdentifier(actionAccessibilityId)
                } else {
                    button
                }
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.line).frame(height: 1)
        }
    }
}
