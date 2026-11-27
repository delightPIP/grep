import SwiftUI

// `휴지통` 목록(ARC-008 규칙 5·10, 시안 21 Trash ③).
// 휴지통 번호는 `되살리기`만 받으므로 행을 누르면 `고르기` 대신 `되살리기 <번호>`를 입력줄에 찍는다.
// `휴지통 비우기` 칩은 인자가 다 찬 명령이라 바로 실행하고(MOB-002 규칙 2), 실행 전 확인 시트가 뜬다.

struct TerminalTrashListView: View {
    let header: String
    let rows: [TerminalTrashRow]
    let hasMore: Bool
    let palette: TerminalPalette
    let onStage: (String) -> Void
    let onSubmit: (String) -> Void
    let onMoreRequested: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(header)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.ink)
            ForEach(rows) { row in
                trashRow(row)
            }
            if hasMore {
                Button(action: onMoreRequested) {
                    chipLabel(prefix: "→ ", command: "더 보기")
                        .frame(minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            nextCommands
        }
    }

    private var nextCommands: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("→ ").foregroundStyle(palette.inkMuted)
            Button { onStage("되살리기 ") } label: { chip("되살리기") }
                .buttonStyle(.plain)
                .accessibilityIdentifier("trashHint_revive")
            Text(" 또는 ").foregroundStyle(palette.ink)
            Button { onSubmit("휴지통 비우기") } label: { chip("휴지통 비우기") }
                .buttonStyle(.plain)
                .accessibilityIdentifier("trashHint_empty")
        }
        .font(.system(size: 14, design: .monospaced))
        .frame(minHeight: 44, alignment: .leading)
    }

    private func trashRow(_ row: TerminalTrashRow) -> some View {
        Button {
            onStage("되살리기 \(row.number)")
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Text("\(row.number)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.inkMuted)
                    .frame(minWidth: 34, alignment: .trailing)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(palette.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(row.meta)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(palette.inkMuted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .frame(minHeight: 56, alignment: .center)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("되살리기 \(row.number)를 입력줄에 찍음")
        .accessibilityIdentifier("trashRow_\(row.number)")
    }

    private func chip(_ command: String) -> some View {
        Text(command)
            .bold()
            .underline()
            .foregroundStyle(palette.command)
    }

    private func chipLabel(prefix: String, command: String) -> some View {
        HStack(spacing: 0) {
            Text(prefix).foregroundStyle(palette.inkMuted)
            chip(command)
        }
        .font(.system(size: 14, weight: .bold, design: .monospaced))
    }
}
