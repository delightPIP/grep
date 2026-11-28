import SwiftUI

// MARK: - Command Bar (MCommandBar.dc.html / MobileKeys.dc.html)

struct TerminalCommandBar: View {
    let input: String
    @Binding var showAllKeys: Bool
    var isInputFocused: FocusState<Bool>.Binding
    let palette: TerminalPalette
    let onInputChange: (String) -> Void
    let onSubmit: (String) -> Void
    let onPaste: (String) -> Void

    var body: some View {
        VStack(spacing: 8) {
            if showAllKeys {
                expandedCommandGrid
            } else {
                compactCommandRow
            }
            inputRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(palette.surfaceRaised)
        .overlay(alignment: .top) {
            Rectangle().fill(palette.line).frame(height: 1)
        }
    }

    private var compactCommandRow: some View {
        HStack(spacing: 8) {
            commandKey("최근") {
                onSubmit("최근")
            }
            commandKey("찾기 _") {
                onInputChange("찾기 ")
                isInputFocused.wrappedValue = true
            }
            commandKey("고르기 _") {
                onInputChange("고르기 ")
                isInputFocused.wrappedValue = true
            }
            commandKey("더보기") {
                showAllKeys.toggle()
            }
        }
    }

    private var expandedCommandGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("명령 전체")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.ink)
                Text("_ 는 이어 치기")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(palette.inkMuted)
                Spacer()
                Button("닫기") {
                    showAllKeys = false
                }
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.command)
                .buttonStyle(.plain)
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
            LazyVGrid(columns: columns, spacing: 8) {
                expandedKey("최근", desc: "바로 실행") {
                    showAllKeys = false
                    onSubmit("최근")
                }
                expandedKey("찾기 _", desc: "검색어 치기") {
                    showAllKeys = false
                    onInputChange("찾기 ")
                    isInputFocused.wrappedValue = true
                }
                expandedKey("고르기 _", desc: "번호 치기") {
                    showAllKeys = false
                    onInputChange("고르기 ")
                    isInputFocused.wrappedValue = true
                }
                expandedKey("담기 _", desc: "링크·글 저장") {
                    showAllKeys = false
                    onInputChange("담기 ")
                    isInputFocused.wrappedValue = true
                }
                expandedKey("도움말", desc: "바로 실행") {
                    showAllKeys = false
                    onSubmit("도움말")
                }
                expandedKey("로그아웃", desc: "세션 종료") {
                    showAllKeys = false
                    onSubmit("로그아웃")
                }
            }
        }
    }

    private func commandKey(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.command)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(palette.line, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func expandedKey(_ label: String, desc: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.command)
                Text(desc)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(palette.inkMuted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(palette.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var inputRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Text("그렙 ~ $")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.prompt)
                TextField(
                    "",
                    text: Binding(
                        get: { input },
                        set: { newValue in
                            let wasEmpty = input.isEmpty
                            if wasEmpty, looksLikePastedURL(newValue) {
                                onPaste(newValue)
                            } else {
                                onInputChange(newValue)
                            }
                        }
                    ),
                    prompt: Text("명령 · 링크").foregroundStyle(palette.inkMuted)
                )
                .font(.system(size: 16, design: .monospaced))
                .foregroundStyle(palette.ink)
                .tint(palette.prompt)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.send)
                .focused(isInputFocused)
                .onSubmit {
                    submitCurrentInput()
                }
                .accessibilityIdentifier("terminalInputField")
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isInputFocused.wrappedValue ? palette.command : palette.line,
                        lineWidth: isInputFocused.wrappedValue ? 2 : 1
                    )
            )

            Button(action: submitCurrentInput) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(palette.surface)
                    .frame(width: 44, height: 44)
                    .background(palette.prompt)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("실행")
            .accessibilityIdentifier("terminalRunButton")
        }
    }

    private func submitCurrentInput() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSubmit(input)
    }

    private func looksLikePastedURL(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count > 10 && (trimmed.hasPrefix("https://") || trimmed.hasPrefix("http://"))
    }
}
