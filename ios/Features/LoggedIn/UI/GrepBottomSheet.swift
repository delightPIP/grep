import SwiftUI

// `/Users/carti/Desktop/grep-design` 공용 모바일 부품.

/// 시안 `MSheet.dc.html`.
struct GrepBottomSheet: View {
    let title: String
    let lines: [String]
    let primaryLabel: String
    let primaryKind: GrepButtonKind
    let cancelLabel: String
    let onPrimary: () -> Void
    let onCancel: () -> Void

    private let palette = LoggedInPalette.dark

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)
                .accessibilityLabel("시트 닫기")

            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(palette.line)
                    .frame(width: 36, height: 4)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.ink)

                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 14))
                        .foregroundStyle(palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    GrepUIButton(primaryLabel, kind: primaryKind, size: .lg, fullWidth: true) {
                        onPrimary()
                    }
                    .accessibilityIdentifier("sheetPrimaryButton")

                    GrepUIButton(cancelLabel, kind: .secondary, size: .lg, fullWidth: true) {
                        onCancel()
                    }
                    .accessibilityIdentifier("sheetCancelButton")
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface.ignoresSafeArea(edges: .bottom))
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8))
            .overlay(alignment: .top) {
                Rectangle().fill(palette.line).frame(height: 1)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("confirmBottomSheet")
    }
}
