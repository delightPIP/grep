import SwiftUI

// 넘기기가 바로 끝나지 않은 경우의 블록: 복사 실패, 5건 초과 확인.

struct TerminalHandoffFailedView: View {
    let reasonLabel: String
    let preview: String?
    let isClipboardDenied: Bool
    let palette: TerminalPalette
    let onSubmit: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TerminalStatusRow(tone: .error, boldPrefix: nil, text: "복사 안 됨: \(reasonLabel)  선택은 남겨 둠", palette: palette)
            if isClipboardDenied, let preview {
                Text(preview)
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
            HStack(spacing: 0) {
                Text(isClipboardDenied ? "→ 직접 복사: 길게 눌러 복사 · 다시: " : "→ ")
                    .foregroundStyle(palette.inkMuted)
                Button {
                    onSubmit("넘기기")
                } label: {
                    Text("넘기기")
                        .bold()
                        .underline()
                        .foregroundStyle(palette.command)
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 14, design: .monospaced))
            .frame(minHeight: 36, alignment: .leading)
        }
    }
}

struct TerminalHandoffConfirmView: View {
    let total: Int
    let choices: [TerminalChoiceItem]
    let palette: TerminalPalette
    let onSubmit: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TerminalStatusRow(tone: .warn, boldPrefix: nil, text: "\(total)건: 바로 복사 안 함 (5건 초과)", palette: palette)
            VStack(spacing: 6) {
                ForEach(choices) { choice in
                    Button {
                        onSubmit(choice.command)
                    } label: {
                        HStack(spacing: 8) {
                            Text(choice.command)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(palette.command)
                            Text(choice.label)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(palette.ink)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .background(palette.surfaceRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(palette.line, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("handoffChoice_\(choice.command)")
                }
            }
        }
    }
}
