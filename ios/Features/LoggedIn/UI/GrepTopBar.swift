import SwiftUI

// `/Users/carti/Desktop/grep-design` 공용 모바일 부품.

/// 시안 `MTopBar.dc.html`.
struct GrepTopBar: View {
    let title: String
    let status: String
    let plain: Bool
    let statusAccessibilityId: String?

    init(
        title: String,
        status: String = "",
        plain: Bool = false,
        statusAccessibilityId: String? = nil
    ) {
        self.title = title
        self.status = status
        self.plain = plain
        self.statusAccessibilityId = statusAccessibilityId
    }

    private let palette = LoggedInPalette.dark

    var body: some View {
        HStack(spacing: 8) {
            if plain {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
            } else {
                HStack(spacing: 4) {
                    Text("그렙")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.prompt)
                    Text("— \(title)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.ink)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if !status.isEmpty {
                let statusText = Text(status)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(palette.inkMuted)
                    .lineLimit(1)
                if let statusAccessibilityId {
                    statusText.accessibilityIdentifier(statusAccessibilityId)
                } else {
                    statusText
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(palette.surfaceRaised.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.line).frame(height: 1)
        }
    }
}
