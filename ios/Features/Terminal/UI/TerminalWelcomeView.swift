import SwiftUI

// MARK: - Welcome (MobileHome.dc.html)

struct TerminalWelcomeView: View {
    let itemCountLine: String?
    let offersSamples: Bool
    @Binding var showShareGuide: Bool
    let palette: TerminalPalette
    let onSamplesRequest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                TerminalMoleView(size: 48)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("그렙 ~ $")
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.prompt)
                    Text("담기 → 찾기 → 넘기기")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(palette.inkMuted)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                if let itemCountLine {
                    TerminalStatusRow(tone: .info, boldPrefix: nil, text: itemCountLine, palette: palette)
                }
                TerminalStatusRow(tone: .info, boldPrefix: nil, text: "저장: 다른 앱에서 공유 → 그렙, 또는 링크·글 붙여 넣기", palette: palette)
            }

            if offersSamples {
                samplesHint
            }

            if showShareGuide {
                shareGuideCard
            }

            VStack(alignment: .leading, spacing: 4) {
                helpRow("최근", "최근 자료 목록")
                helpRow("찾기", "검색")
                helpRow("고르기", "번호로 선택")
                helpRow("넘기기", "AI 앱으로 공유 또는 복사")
                helpRow("도움말", "명령 목록")
            }

            Text("→ 아래 버튼을 누르면 실행. _ 붙은 명령은 뒤를 이어 침. 나머지 명령: 더보기")
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("terminalWelcome")
    }

    /// ARC-010 규칙 1·2: 0건일 때만 보이고, 누르면 입력줄을 거치지 않고 바로 저장한다(웹 `SamplesChip`과 같음).
    private var samplesHint: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("→ ")
                .foregroundStyle(palette.inkMuted)
            Button(action: onSamplesRequest) {
                Text("샘플 8건으로 해 보기")
                    .bold()
                    .underline()
                    .foregroundStyle(palette.command)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("samplesChip")
            Text(" 또는 아래에 링크 붙여 넣기")
                .foregroundStyle(palette.ink)
        }
        .font(.system(size: 14, design: .monospaced))
        .frame(minHeight: 44, alignment: .leading)
    }

    private var shareGuideCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            (
                Text("공유 시트에 그렙 꺼내 두기 ")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.ink)
                + Text("(처음 한 번)")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(palette.inkMuted)
            )
            guideStep("1", "다른 앱에서 공유 버튼")
            guideStep("2", "앱 아이콘 줄 끝 \"더 보기\"")
            guideStep("3", "편집 → 그렙을 즐겨찾기에 추가")
            Button {
                showShareGuide = false
            } label: {
                Text("알겠음")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.command)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(palette.line, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(palette.line, lineWidth: 1)
        )
    }

    private func guideStep(_ number: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(number)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.command)
                .frame(width: 16, alignment: .leading)
            Text(text)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(palette.ink)
        }
    }

    private func helpRow(_ command: String, _ description: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(command)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.command)
                .frame(width: 64, alignment: .leading)
            Text(description)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(palette.ink)
        }
    }
}
