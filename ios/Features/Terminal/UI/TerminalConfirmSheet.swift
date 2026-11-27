import SwiftUI

// 확인 질문 시트(시안 M9 MobileSheets ②, MSheet).
// 실행 낱말 버튼은 그 낱말을 친 것과 같고, `취소`와 시트 밖 누르기는 빈 입력과 같다(MOB-002 규칙 4, COM-007 규칙 5·6).

struct TerminalConfirmSheet: View {
    let prompt: TerminalConfirmPrompt
    let palette: TerminalPalette
    let onAnswer: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(prompt.question)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 8) {
                answerButton(
                    label: prompt.answer,
                    foreground: palette.surface,
                    background: palette.danger,
                    identifier: "confirmAnswer_\(prompt.answer)",
                    action: onAnswer
                )
                answerButton(
                    label: "취소",
                    foreground: palette.ink,
                    background: palette.surfaceRaised,
                    identifier: "confirmCancel",
                    action: onCancel
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func answerButton(
        label: String,
        foreground: Color,
        background: Color,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(palette.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

/// `pendingConfirm`이 있으면 시트를 띄운다. 시트 높이는 내용에 맞춘다(Dynamic Type에서도 잘리지 않게).
struct TerminalConfirmSheetModifier: ViewModifier {
    let prompt: TerminalConfirmPrompt?
    let palette: TerminalPalette
    let onSubmit: (String) -> Void

    @State private var contentHeight: CGFloat = 160

    func body(content: Content) -> some View {
        content.sheet(isPresented: isPresented) {
            if let prompt {
                TerminalConfirmSheet(
                    prompt: prompt,
                    palette: palette,
                    onAnswer: { onSubmit(prompt.answer) },
                    onCancel: { onSubmit("") }
                )
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
                .presentationDetents([.height(contentHeight)])
                .presentationDragIndicator(.visible)
                .presentationBackground(palette.surface)
                .presentationCornerRadius(8)
                .preferredColorScheme(.dark)
            }
        }
    }

    /// 사용자가 시트를 내렸을 때만 `set(false)`가 불린다. 답이 이미 들어가 확인이 끝났으면 다시 취소하지 않는다.
    private var isPresented: Binding<Bool> {
        Binding(
            get: { prompt != nil },
            set: { presented in
                if !presented, prompt != nil {
                    onSubmit("")
                }
            }
        )
    }
}
