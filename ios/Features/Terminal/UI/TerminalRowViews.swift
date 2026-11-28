import SwiftUI

// 로그 줄 공용 행: 프롬프트 줄, 상태 줄(✓ · ! ✗).

struct TerminalPromptRow: View {
    let command: String
    let failed: Bool
    let palette: TerminalPalette

    var body: some View {
        let parts = splitFirstWord(command)
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("그렙 ~ $")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(failed ? palette.danger : palette.prompt)
            (
                Text(parts.verb)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.command)
                + Text(parts.rest)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(palette.ink)
            )
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func splitFirstWord(_ command: String) -> (verb: String, rest: String) {
        let trimmed = command.trimmingCharacters(in: .whitespaces)
        guard let spaceIndex = trimmed.firstIndex(where: \.isWhitespace) else {
            return (trimmed, "")
        }
        return (String(trimmed[..<spaceIndex]), String(trimmed[spaceIndex...]))
    }
}

struct TerminalStatusRow: View {
    let tone: TerminalLineTone
    let boldPrefix: String?
    let text: String
    let palette: TerminalPalette

    var body: some View {
        let style = toneStyle(tone)
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(style.symbol)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(style.color)
                .frame(width: 14, alignment: .leading)
                .accessibilityHidden(true)
            Group {
                if let boldPrefix {
                    Text(boldPrefix).bold().foregroundStyle(style.boldColor) + Text(text)
                } else {
                    Text(text)
                }
            }
            .font(.system(size: 14, design: .monospaced))
            .foregroundStyle(palette.ink)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func toneStyle(_ tone: TerminalLineTone) -> (symbol: String, color: Color, boldColor: Color) {
        switch tone {
        case .ok: ("✓", palette.prompt, palette.ink)
        case .info: ("·", palette.command, palette.ink)
        case .warn: ("!", palette.notice, palette.notice)
        case .error: ("✗", palette.danger, palette.danger)
        }
    }
}

/// 누르면 명령을 입력줄에 올리는 힌트 줄. `→ 예: 찾기 결제` 같은 모양.
struct TerminalCommandHintRow: View {
    let prefix: String
    let command: String
    let suffix: String
    let palette: TerminalPalette
    let onStage: (String) -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            if !prefix.isEmpty {
                Text(prefix)
                    .foregroundStyle(palette.inkMuted)
            }
            Button {
                onStage(command)
            } label: {
                Text(command)
                    .bold()
                    .underline()
                    .foregroundStyle(palette.command)
            }
            .buttonStyle(.plain)
            if !suffix.isEmpty {
                Text(suffix)
                    .foregroundStyle(palette.ink)
            }
        }
        .font(.system(size: 14, design: .monospaced))
        .frame(minHeight: 32, alignment: .leading)
    }
}
