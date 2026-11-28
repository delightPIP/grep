import SwiftUI

// `/Users/carti/Desktop/grep-design` 공용 모바일 부품.

/// 시안 `MPickBar.dc.html` (summary 모드).
struct GrepPickBar: View {
    let count: Int
    let summary: String
    let onMoveToTerminal: () -> Void
    let onClear: () -> Void

    private let palette = LoggedInPalette.dark

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("선택 \(count)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.command)
                Text(summary)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(palette.inkMuted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            HStack(spacing: 8) {
                GrepUIButton(
                    "터미널에서 넘기기",
                    kind: .primary,
                    size: .md,
                    fullWidth: true,
                    icon: "square.and.arrow.up"
                ) {
                    onMoveToTerminal()
                }
                .accessibilityIdentifier("pickBarHandoffButton")

                GrepUIButton(
                    "해제",
                    kind: .secondary,
                    size: .md
                ) {
                    onClear()
                }
                .accessibilityIdentifier("pickBarClearButton")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(palette.surfaceRaised.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(palette.line).frame(height: 1)
        }
        .accessibilityIdentifier("archivePickBar")
    }
}
