import SwiftUI

// `고치기 <번호>` 편집 칸(commands 3절 고치기, 시안 20 Edit ①·④).
// 웹처럼 모달 없이 출력 끝에 제목·`요약 (직접 고침)` 두 칸을 연다.
// shortcut: 웹은 열 때 제목 칸에 초점을 두지만, 목록 안에서 `@FocusState`를 바로 주는 방법이 시뮬레이터에서 먹지 않아 뺐다. 칸을 누르면 초점이 간다.
// 휴대폰 키보드에는 Esc·Tab이 없으므로 `저장`·`취소` 버튼으로 답하고, 리턴은 다음 칸 → 저장 순서다.

struct TerminalReviseForm: View {
    let revising: TerminalRevisePresentation
    let palette: TerminalPalette
    let onSubmit: (Int, String, String) -> Void
    let onCancel: () -> Void

    private enum Field: Hashable {
        case title
        case summary
    }

    @State private var title: String
    @State private var summary: String
    @FocusState private var focusedField: Field?

    init(
        revising: TerminalRevisePresentation,
        palette: TerminalPalette,
        onSubmit: @escaping (Int, String, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.revising = revising
        self.palette = palette
        self.onSubmit = onSubmit
        self.onCancel = onCancel
        _title = State(initialValue: revising.title)
        _summary = State(initialValue: revising.summary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            (Text("고치기 \(revising.number)").bold().foregroundColor(palette.command) + Text("  \(revising.title)"))
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(palette.ink)
                .lineLimit(1)
                .truncationMode(.tail)

            field(label: "제목", text: $title, focus: .title, submitLabel: .next) {
                focusedField = .summary
            }
            .accessibilityIdentifier("reviseTitleField")

            field(label: "요약 (직접 고침)", text: $summary, focus: .summary, submitLabel: .done) {
                submit()
            }
            .accessibilityIdentifier("reviseSummaryField")

            HStack(spacing: 8) {
                button("저장", foreground: palette.surface, background: palette.prompt, identifier: "reviseSaveButton", action: submit)
                button("취소", foreground: palette.ink, background: palette.surfaceRaised, identifier: "reviseCancelButton", action: onCancel)
            }
        }
        .padding(12)
        .background(palette.surfaceRaised.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(palette.line, lineWidth: 1))
    }

    private func submit() {
        onSubmit(revising.number, title, summary)
    }

    private func field(
        label: String,
        text: Binding<String>,
        focus: Field,
        submitLabel: SubmitLabel,
        onReturn: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(palette.inkMuted)
            TextField("", text: text)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(palette.ink)
                .tint(palette.prompt)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: focus)
                .submitLabel(submitLabel)
                .onSubmit(onReturn)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .frame(minHeight: 44, alignment: .leading)
                .background(palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(focusedField == focus ? palette.command : palette.line, lineWidth: 1)
                )
                .accessibilityLabel(label)
        }
    }

    private func button(
        _ label: String,
        foreground: Color,
        background: Color,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(palette.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}
