import SwiftUI

// MARK: - Log Line (M1 / M3)

/// 로그 블록의 한 줄을 종류에 맞는 하위 뷰로 그린다.
struct TerminalLineView: View {
    let line: TerminalOutputBlockLine
    let palette: TerminalPalette
    let welcome: TerminalWelcomeView
    let onStage: (String) -> Void
    let onSubmit: (String) -> Void
    let onMoreRequested: () -> Void

    var body: some View {
        switch line {
        case .prompt(let command, let failed):
            TerminalPromptRow(command: command, failed: failed, palette: palette)
        case .status(let tone, let boldPrefix, let body):
            TerminalStatusRow(tone: tone, boldPrefix: boldPrefix, text: body, palette: palette)
        case .plain(let text, let dim):
            Text(text)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(dim ? palette.inkMuted : palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        case .commandHint(let prefix, let command, let suffix):
            TerminalCommandHintRow(prefix: prefix, command: command, suffix: suffix, palette: palette, onStage: onStage)
        case .itemRow(let item):
            TerminalItemRowView(item: item, palette: palette, onSubmit: onSubmit)
        case .trashList(let header, let rows, let hasMore):
            TerminalTrashListView(
                header: header,
                rows: rows,
                hasMore: hasMore,
                palette: palette,
                onStage: onStage,
                onSubmit: onSubmit,
                onMoreRequested: onMoreRequested
            )
        case .list(let header, let items, let hasMore):
            TerminalListBlockView(
                header: header,
                items: items,
                hasMore: hasMore,
                palette: palette,
                onSubmit: onSubmit,
                onMoreRequested: onMoreRequested
            )
        case .handedOff(let result):
            TerminalHandoffBlockView(result: result, palette: palette)
        case .handoffFailed(let reasonLabel, let preview, let isClipboardDenied):
            TerminalHandoffFailedView(
                reasonLabel: reasonLabel,
                preview: preview,
                isClipboardDenied: isClipboardDenied,
                palette: palette,
                onSubmit: onSubmit
            )
        case .handoffConfirm(let total, let choices):
            TerminalHandoffConfirmView(total: total, choices: choices, palette: palette, onSubmit: onSubmit)
        case .guide(let rows):
            TerminalGuideBlockView(rows: rows, palette: palette, onStage: onStage)
        case .welcome:
            welcome
        }
    }
}
