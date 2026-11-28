import SwiftUI

// MARK: - Selection Bar (MPickBar.dc.html / commands 6절 고르기)

struct TerminalSelectionBar: View {
    let selection: [TerminalItemRef]
    let palette: TerminalPalette
    let onSubmit: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 시안 MPickBar: 고른 자료마다 `×` 칩, 끝에 `모두 해제`. 눌러도 친 명령과 같게 기록한다(commands 3절 고르기, MOB-002 규칙 3).
            HStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(selection) { item in
                            selectionChip(item)
                        }
                    }
                }
                Button {
                    onSubmit("고르기 비우기")
                } label: {
                    Text("모두 해제")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.inkMuted)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("terminalPickBarClearButton")
            }

            HStack(spacing: 8) {
                Button {
                    onSubmit("넘기기")
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .bold))
                        Text("넘기기 \(selection.count)건")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(palette.surface)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(palette.prompt)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("terminalPickBarHandoffButton")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(palette.surfaceRaised)
        .overlay(alignment: .top) {
            Rectangle().fill(palette.line).frame(height: 1)
        }
        .accessibilityIdentifier("terminalSelectionBar")
    }

    private func selectionChip(_ item: TerminalItemRef) -> some View {
        Button {
            onSubmit("고르기 빼기 \(item.number)")
        } label: {
            HStack(spacing: 6) {
                // 시안 MPickBar: 굵은 `<종류 낱말> <번호>`(ARC-003 규칙 14) 뒤에 제목.
                Text(item.tag)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.command)
                Text(item.title)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                    .frame(maxWidth: 160, alignment: .leading)
                Text("×")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.inkMuted)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .background(palette.select)
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("빼기: \(item.tag) \(item.title)")
        .accessibilityIdentifier("pickChip_\(item.number)")
    }
}
