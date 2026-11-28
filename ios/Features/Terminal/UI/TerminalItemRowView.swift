import SwiftUI

// MARK: - Mobile Result Row (MList.dc.html)

struct TerminalItemRowView: View {
    let item: TerminalItemRow
    let palette: TerminalPalette
    let onSubmit: (String) -> Void

    var body: some View {
        Button {
            onSubmit("고르기 \(item.number)")
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Text(item.isPicked ? "▸\(item.number)" : "\(item.number)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(item.isPicked ? palette.command : palette.inkMuted)
                    .frame(minWidth: 34, alignment: .trailing)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(palette.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if !item.meta.isEmpty {
                        Text(item.meta)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(palette.inkMuted)
                            .lineLimit(1)
                    }

                    if item.summary != nil || item.matchLabel != nil || !item.tags.isEmpty {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            if let summary = item.summary {
                                Text(summary)
                                    .foregroundStyle(item.summaryIsWarning ? palette.notice : palette.inkMuted)
                            }
                            if let matchLabel = item.matchLabel {
                                Text("· \(matchLabel)")
                                    .foregroundStyle(palette.inkMuted)
                            }
                            if !item.tags.isEmpty {
                                Text(item.tags.map { "#\($0)" }.joined(separator: " "))
                                    .foregroundStyle(palette.inkMuted)
                            }
                        }
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .frame(minHeight: 56, alignment: .center)
            .background(item.isPicked ? palette.select : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

/// 자료 목록 블록: 머리 줄, 구분선, 행, `더 보기`.
struct TerminalListBlockView: View {
    let header: String?
    let items: [TerminalItemRow]
    let hasMore: Bool
    let palette: TerminalPalette
    let onSubmit: (String) -> Void
    let onMoreRequested: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let header {
                Text(header)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.ink)
            }
            ForEach(items) { item in
                if let divider = item.dividerBefore {
                    Text(divider)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(palette.inkMuted)
                        .padding(.top, 6)
                        .accessibilityLabel(divider.trimmingCharacters(in: CharacterSet(charactersIn: "─ ")))
                }
                TerminalItemRowView(item: item, palette: palette, onSubmit: onSubmit)
            }
            if hasMore {
                Button(action: onMoreRequested) {
                    HStack(spacing: 4) {
                        Text("→")
                            .foregroundStyle(palette.inkMuted)
                        Text("더 보기")
                            .underline()
                            .foregroundStyle(palette.command)
                    }
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .frame(minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("moreButton")
            }
        }
    }
}
