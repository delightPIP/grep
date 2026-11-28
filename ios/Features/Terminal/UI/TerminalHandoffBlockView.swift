import SwiftUI

struct TerminalHandoffBlockView: View {
    let result: TerminalHandoffPresentation
    let palette: TerminalPalette
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("✓")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.prompt)
                    .frame(width: 14, alignment: .leading)
                Text("복사됨  \(result.items.count)건 · \(result.charCountText) (제목·출처·저장 시각·요약)")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(result.items) { item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(item.number)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.inkMuted)
                        .frame(minWidth: 34, alignment: .trailing)
                    Text(item.title)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(palette.ink)
                        .lineLimit(1)
                }
            }

            if result.missingSummaryCount > 0 {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("!")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.notice)
                        .frame(width: 14, alignment: .leading)
                    Text("요약 없음 \(result.missingSummaryCount)건")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(palette.notice)
                }
            }

            HStack(spacing: 12) {
                Button {
                    isExpanded.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Text("· 미리보기:")
                            .foregroundStyle(palette.inkMuted)
                        Text(isExpanded ? "접기" : "펼치기")
                            .bold()
                            .underline()
                            .foregroundStyle(palette.command)
                    }
                    .font(.system(size: 14, design: .monospaced))
                    .frame(minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("handoffPreviewToggle")

                ShareLink(item: result.text) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .bold))
                        Text("다른 앱으로 공유")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(palette.surface)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 36)
                    .background(palette.prompt)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("handoffShareButton")
            }

            if isExpanded {
                Text(result.text)
                    .font(.system(size: 13))
                    .foregroundStyle(palette.ink)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(palette.line, lineWidth: 1)
                    )
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("·")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.command)
                    .frame(width: 14, alignment: .leading)
                Text("클립보드에 있음 → AI 도구 입력창에 붙여 넣기")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(palette.inkMuted)
            }
        }
    }
}
