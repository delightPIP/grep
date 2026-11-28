import SwiftUI

// MARK: - Top Bar (MTopBar.dc.html)

struct TerminalTopBar: View {
    let title: String
    let statusText: String
    let isOffline: Bool
    let palette: TerminalPalette

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Text("그렙")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.prompt)
                Text("— \(title)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(statusText)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(isOffline ? palette.notice : palette.inkMuted)
                .lineLimit(1)
                .accessibilityIdentifier("terminalStatusText")
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(palette.surfaceRaised.ignoresSafeArea(edges: .top))
    }
}
