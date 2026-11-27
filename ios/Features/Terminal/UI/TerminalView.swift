import SwiftUI

// 터미널 순수 SwiftUI 뷰(ADR-0015).
// 배치는 `/Users/carti/Desktop/grep-design`의 M1(MobileHome)·M2(MobileKeys)·M3(MobileSearch)·MTopBar·MCommandBar·MList 기준.

public struct TerminalView: View {
    let presentation: TerminalPresentation
    let scrollToBottomTrigger: Int
    let onInputChange: (String) -> Void
    let onSubmit: (String) -> Void
    let onPaste: (String) -> Void
    let onMoreRequested: () -> Void
    let onKeyboardVisibilityChange: ((Bool) -> Void)?

    @State private var showAllKeys = false
    @State private var showShareGuide = true
    @FocusState private var isInputFocused: Bool

    public init(
        presentation: TerminalPresentation,
        scrollToBottomTrigger: Int = 0,
        onInputChange: @escaping (String) -> Void,
        onSubmit: @escaping (String) -> Void,
        onPaste: @escaping (String) -> Void,
        onMoreRequested: @escaping () -> Void,
        onKeyboardVisibilityChange: ((Bool) -> Void)? = nil
    ) {
        self.presentation = presentation
        self.scrollToBottomTrigger = scrollToBottomTrigger
        self.onInputChange = onInputChange
        self.onSubmit = onSubmit
        self.onPaste = onPaste
        self.onMoreRequested = onMoreRequested
        self.onKeyboardVisibilityChange = onKeyboardVisibilityChange
    }

    private let palette = TerminalPalette.dark

    public var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().overlay(palette.line)
            logScrollArea
            if !presentation.selection.isEmpty {
                selectionBar
            }
            commandBar
        }
        .background(palette.surface.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onChange(of: isInputFocused) { _, focused in
            onKeyboardVisibilityChange?(focused)
        }
    }

    // MARK: - Top Bar (MTopBar.dc.html)

    private var topBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Text("그렙")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.prompt)
                Text("— \(presentation.title)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(presentation.statusText)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(presentation.isOffline ? palette.notice : palette.inkMuted)
                .lineLimit(1)
                .accessibilityIdentifier("terminalStatusText")
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(palette.surfaceRaised.ignoresSafeArea(edges: .top))
    }

    // MARK: - Log Body (M1 / M3)

    private var logScrollArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if presentation.blocks.isEmpty {
                        welcomeBlock
                    } else {
                        ForEach(presentation.blocks) { block in
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(block.lines.enumerated()), id: \.offset) { _, line in
                                    renderLine(line)
                                }
                            }
                            .id(block.id)
                        }
                    }
                    Color.clear.frame(height: 1).id("terminalBottom")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(palette.surface)
            .onChange(of: presentation.blocks.count) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("terminalBottom", anchor: .bottom)
                }
            }
            .onChange(of: scrollToBottomTrigger) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("terminalBottom", anchor: .bottom)
                }
            }
        }
    }

    @ViewBuilder
    private func renderLine(_ line: TerminalOutputBlockLine) -> some View {
        switch line {
        case .prompt(let command, let failed):
            promptRow(command: command, failed: failed)
        case .status(let tone, let boldPrefix, let body):
            statusRow(tone: tone, boldPrefix: boldPrefix, body: body)
        case .plain(let text, let dim):
            Text(text)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(dim ? palette.inkMuted : palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        case .commandHint(let prefix, let command, let suffix):
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                if !prefix.isEmpty {
                    Text(prefix)
                        .foregroundStyle(palette.inkMuted)
                }
                Button {
                    onInputChange(command)
                    isInputFocused = true
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
        case .itemRow(let item):
            mobileItemRow(item)
        case .list(let header, let items, let hasMore):
            VStack(alignment: .leading, spacing: 4) {
                if let header {
                    Text(header)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.ink)
                }
                ForEach(items) { item in
                    mobileItemRow(item)
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
        case .handedOff(let result):
            TerminalHandoffBlockView(result: result, palette: palette)
        case .handoffFailed(let reasonLabel, let preview, let isClipboardDenied):
            VStack(alignment: .leading, spacing: 6) {
                statusRow(tone: .error, boldPrefix: nil, body: "복사 안 됨: \(reasonLabel)  선택은 남겨 둠")
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
        case .handoffConfirm(let total, let choices):
            VStack(alignment: .leading, spacing: 8) {
                statusRow(tone: .warn, boldPrefix: nil, body: "\(total)건: 바로 복사 안 함 (5건 초과)")
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
        case .guide(let rows):
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
                        onInputChange("찾기 결제 | 넘기기")
                        isInputFocused = true
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
        case .welcome:
            welcomeBlock
        }
    }

    private func promptRow(command: String, failed: Bool) -> some View {
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

    private func statusRow(tone: TerminalLineTone, boldPrefix: String?, body: String) -> some View {
        let style = toneStyle(tone)
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(style.symbol)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(style.color)
                .frame(width: 14, alignment: .leading)
                .accessibilityHidden(true)
            Group {
                if let boldPrefix {
                    Text(boldPrefix).bold().foregroundStyle(style.boldColor) + Text(body)
                } else {
                    Text(body)
                }
            }
            .font(.system(size: 14, design: .monospaced))
            .foregroundStyle(palette.ink)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Mobile Result Row (MList.dc.html)

    private func mobileItemRow(_ item: TerminalItemRow) -> some View {
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

    // MARK: - Selection Bar (MPickBar.dc.html / commands 6절 고르기)

    private var selectionBar: some View {
        let summary = presentation.selection.map { "\($0.number) \($0.title)" }.joined(separator: " · ")
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("선택 \(presentation.selection.count)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.command)
                Text(summary)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(palette.inkMuted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            HStack(spacing: 8) {
                Button {
                    onSubmit("넘기기")
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .bold))
                        Text("넘기기 \(presentation.selection.count)건")
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

    // MARK: - Welcome (MobileHome.dc.html)

    private var welcomeBlock: some View {
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
                statusRow(tone: .info, boldPrefix: nil, body: "자료 0건")
                statusRow(tone: .info, boldPrefix: nil, body: "저장: 다른 앱에서 공유 → 그렙, 또는 링크·글 붙여 넣기")
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

    // MARK: - Command Bar (MCommandBar.dc.html / MobileKeys.dc.html)

    private var commandBar: some View {
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
                isInputFocused = true
            }
            commandKey("고르기 _") {
                onInputChange("고르기 ")
                isInputFocused = true
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
                    isInputFocused = true
                }
                expandedKey("고르기 _", desc: "번호 치기") {
                    showAllKeys = false
                    onInputChange("고르기 ")
                    isInputFocused = true
                }
                expandedKey("담기 _", desc: "링크·글 저장") {
                    showAllKeys = false
                    onInputChange("담기 ")
                    isInputFocused = true
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
                        get: { presentation.input },
                        set: { newValue in
                            let wasEmpty = presentation.input.isEmpty
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
                .focused($isInputFocused)
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
                    .stroke(isInputFocused ? palette.command : palette.line, lineWidth: isInputFocused ? 2 : 1)
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
        let trimmed = presentation.input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSubmit(presentation.input)
    }

    private func looksLikePastedURL(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count > 10 && (trimmed.hasPrefix("https://") || trimmed.hasPrefix("http://"))
    }

    private func splitFirstWord(_ command: String) -> (verb: String, rest: String) {
        let trimmed = command.trimmingCharacters(in: .whitespaces)
        guard let spaceIndex = trimmed.firstIndex(where: \.isWhitespace) else {
            return (trimmed, "")
        }
        return (String(trimmed[..<spaceIndex]), String(trimmed[spaceIndex...]))
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

private struct TerminalHandoffBlockView: View {
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

private struct TerminalMoleView: View {
    let size: CGFloat

    private static let rows = [
        "................", "................", ".....oooooo.....", "....ommmmmmo....",
        "...ommmmmmmmo...", "...omommmmomo...", "..ommomssmommo..", "..ommmssssmmmo..",
        "..ohhmmmmmmhho..", ".ohhhmmMMmmhhho.", ".ommmmMMMMmmmmo.", "..ommmmmmmmmmo..",
        ".rrommmmmmmmorr.", "rrrRrrrrrrRrrrrr", ".rrrrrRrrrrrrrr.", "................",
    ]

    private static let colors: [Character: Color] = [
        "M": Color(red: 0x4a / 255, green: 0x44 / 255, blue: 0x60 / 255),
        "R": Color(red: 0x6a / 255, green: 0x42 / 255, blue: 0x28 / 255),
        "h": Color(red: 0xf5 / 255, green: 0xc9 / 255, blue: 0xa3 / 255),
        "m": Color(red: 0x6c / 255, green: 0x65 / 255, blue: 0x85 / 255),
        "o": Color(red: 0x16 / 255, green: 0x12 / 255, blue: 0x0f / 255),
        "r": Color(red: 0x8a / 255, green: 0x5a / 255, blue: 0x3a / 255),
        "s": Color(red: 0xf2 / 255, green: 0xa0 / 255, blue: 0xa8 / 255),
    ]

    var body: some View {
        Canvas { context, canvasSize in
            let cell = canvasSize.width / 16
            for (y, row) in Self.rows.enumerated() {
                for (x, ch) in row.enumerated() {
                    guard let color = Self.colors[ch] else { continue }
                    let rect = CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell, height: cell)
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: size, height: size)
    }
}

private struct TerminalPalette {
    let bg: Color
    let surface: Color
    let surfaceRaised: Color
    let line: Color
    let ink: Color
    let inkMuted: Color
    let prompt: Color
    let command: Color
    let notice: Color
    let danger: Color
    let select: Color

    static let dark = TerminalPalette(
        bg: Color(red: 0x0b / 255, green: 0x0d / 255, blue: 0x10 / 255),
        surface: Color(red: 0x14 / 255, green: 0x17 / 255, blue: 0x1c / 255),
        surfaceRaised: Color(red: 0x1c / 255, green: 0x20 / 255, blue: 0x27 / 255),
        line: Color(red: 0x2e / 255, green: 0x34 / 255, blue: 0x3d / 255),
        ink: Color(red: 0xe7 / 255, green: 0xe9 / 255, blue: 0xec / 255),
        inkMuted: Color(red: 0x99 / 255, green: 0xa2 / 255, blue: 0xad / 255),
        prompt: Color(red: 0x7f / 255, green: 0xe0 / 255, blue: 0xa3 / 255),
        command: Color(red: 0x86 / 255, green: 0xc8 / 255, blue: 0xff / 255),
        notice: Color(red: 0xf2 / 255, green: 0xc8 / 255, blue: 0x6b / 255),
        danger: Color(red: 0xff / 255, green: 0x8f / 255, blue: 0x86 / 255),
        select: Color(red: 0x1f / 255, green: 0x3a / 255, blue: 0x52 / 255)
    )
}
