import SwiftUI

// 터미널 순수 SwiftUI 뷰(ADR-0015).
// 배치는 `/Users/carti/Desktop/grep-design`의 M1(MobileHome)·M2(MobileKeys)·M3(MobileSearch)·MTopBar·MCommandBar·MList 기준.
// 블록별 하위 뷰: TerminalTopBar, TerminalLineView, TerminalWelcomeView, TerminalSelectionBar, TerminalCommandBar.

public struct TerminalView: View {
    let presentation: TerminalPresentation
    let scrollToBottomTrigger: Int
    let onInputChange: (String) -> Void
    let onSubmit: (String) -> Void
    let onPaste: (String) -> Void
    let onMoreRequested: () -> Void
    let onReviseSubmit: (Int, String, String) -> Void
    let onReviseCancel: () -> Void
    let onSamplesRequest: () -> Void
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
        onReviseSubmit: @escaping (Int, String, String) -> Void = { _, _, _ in },
        onReviseCancel: @escaping () -> Void = {},
        onSamplesRequest: @escaping () -> Void = {},
        onKeyboardVisibilityChange: ((Bool) -> Void)? = nil
    ) {
        self.presentation = presentation
        self.scrollToBottomTrigger = scrollToBottomTrigger
        self.onInputChange = onInputChange
        self.onSubmit = onSubmit
        self.onPaste = onPaste
        self.onMoreRequested = onMoreRequested
        self.onReviseSubmit = onReviseSubmit
        self.onReviseCancel = onReviseCancel
        self.onSamplesRequest = onSamplesRequest
        self.onKeyboardVisibilityChange = onKeyboardVisibilityChange
    }

    private let palette = TerminalPalette.dark

    public var body: some View {
        VStack(spacing: 0) {
            TerminalTopBar(
                title: presentation.title,
                statusText: presentation.statusText,
                isOffline: presentation.isOffline,
                palette: palette
            )
            Divider().overlay(palette.line)
            logScrollArea
            if !presentation.selection.isEmpty {
                TerminalSelectionBar(selection: presentation.selection, palette: palette, onSubmit: onSubmit)
            }
            TerminalCommandBar(
                input: presentation.input,
                showAllKeys: $showAllKeys,
                isInputFocused: $isInputFocused,
                palette: palette,
                onInputChange: onInputChange,
                onSubmit: onSubmit,
                onPaste: onPaste
            )
        }
        .background(palette.surface.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .modifier(TerminalConfirmSheetModifier(
            prompt: presentation.pendingConfirm,
            palette: palette,
            onSubmit: onSubmit
        ))
        .onChange(of: isInputFocused) { _, focused in
            onKeyboardVisibilityChange?(focused)
        }
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
                                    TerminalLineView(
                                        line: line,
                                        palette: palette,
                                        welcome: welcomeBlock,
                                        onStage: stage,
                                        onSubmit: onSubmit,
                                        onMoreRequested: onMoreRequested
                                    )
                                }
                            }
                            .id(block.id)
                        }
                    }
                    if let revising = presentation.revising {
                        TerminalReviseForm(
                            revising: revising,
                            palette: palette,
                            onSubmit: onReviseSubmit,
                            onCancel: onReviseCancel
                        )
                        .id("revise-\(revising.number)")
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
            .onChange(of: presentation.revising) { _, _ in
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

    private var welcomeBlock: TerminalWelcomeView {
        TerminalWelcomeView(
            itemCountLine: presentation.itemCountLine,
            offersSamples: presentation.offersSamples,
            showShareGuide: $showShareGuide,
            palette: palette,
            onSamplesRequest: onSamplesRequest
        )
    }

    /// 명령을 입력줄에 올리고 입력줄에 초점을 준다(실행은 하지 않음).
    private func stage(_ command: String) {
        onInputChange(command)
        isInputFocused = true
    }
}
