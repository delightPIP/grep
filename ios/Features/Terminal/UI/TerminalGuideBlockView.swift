import SwiftUI

/// `도움말` 블록: 저장 안내, 명령 표, 누르면 입력줄에 올리는 예시.
struct TerminalGuideBlockView: View {
    let rows: [TerminalGuideRow]
    let palette: TerminalPalette
    let onStage: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("저장: 링크·글 붙여 넣기, 파일 끌어다 놓기. 명령: 한글·영문 같음")
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(rows) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(row.name)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(palette.command)
                            .frame(width: 66, alignment: .leading)
                        Text(row.english)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(palette.inkMuted)
                            .frame(width: 68, alignment: .leading)
                        Text(row.meaning)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(palette.ink)
                    }
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("→ 예:")
                    .foregroundStyle(palette.inkMuted)
                Button {
                    onStage("찾기 결제 | 넘기기")
                } label: {
                    Text("찾기 결제 | 넘기기")
                        .bold()
                        .underline()
                        .foregroundStyle(palette.command)
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 14, design: .monospaced))
            .frame(minHeight: 32, alignment: .leading)
        }
        .accessibilityIdentifier("terminalGuideBlock")
    }
}
