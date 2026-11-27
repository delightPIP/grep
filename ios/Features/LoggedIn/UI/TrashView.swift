import SwiftUI

/// 설정 › 휴지통 순수 SwiftUI 뷰(ARC-008 규칙 5·6·10·11, 시안 `MobileTrash.dc.html` M11 ①②).
public struct TrashView: View {
    let presentation: TrashPresentation
    let onBack: () -> Void
    let onRefresh: () async -> Void
    let onLoadMore: () -> Void
    let onRevive: (Int) -> Void
    let onEmpty: () -> Void
    let onModalVisibilityChange: ((Bool) -> Void)?

    @State private var showEmptySheet = false

    public init(
        presentation: TrashPresentation,
        onBack: @escaping () -> Void,
        onRefresh: @escaping () async -> Void,
        onLoadMore: @escaping () -> Void,
        onRevive: @escaping (Int) -> Void,
        onEmpty: @escaping () -> Void,
        onModalVisibilityChange: ((Bool) -> Void)? = nil
    ) {
        self.presentation = presentation
        self.onBack = onBack
        self.onRefresh = onRefresh
        self.onLoadMore = onLoadMore
        self.onRevive = onRevive
        self.onEmpty = onEmpty
        self.onModalVisibilityChange = onModalVisibilityChange
    }

    private let palette = LoggedInPalette.dark

    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                GrepTopBar(title: "휴지통", plain: false)
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        backButton
                        if let notice = presentation.notice {
                            noticeLine(notice)
                        }
                        content
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                }
                .refreshable { await onRefresh() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.surface.ignoresSafeArea())

            if showEmptySheet {
                GrepBottomSheet(
                    title: presentation.emptyConfirmTitle,
                    lines: [],
                    primaryLabel: "비우기",
                    primaryKind: .danger,
                    cancelLabel: "취소",
                    onPrimary: {
                        showEmptySheet = false
                        onEmpty()
                    },
                    onCancel: {
                        showEmptySheet = false
                    }
                )
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: showEmptySheet) { _, visible in
            onModalVisibilityChange?(visible)
        }
    }

    private var backButton: some View {
        Button(action: onBack) {
            Text("‹ 설정")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.command)
                .frame(minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("설정으로 돌아가기")
        .accessibilityIdentifier("trashBackButton")
    }

    @ViewBuilder
    private var content: some View {
        if presentation.total == nil, presentation.isLoading {
            ProgressView()
                .tint(palette.inkMuted)
                .frame(maxWidth: .infinity, minHeight: 88)
        } else if presentation.isEmpty {
            Text("휴지통 비어 있음")
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(palette.inkMuted)
                .frame(minHeight: 44, alignment: .leading)
                .accessibilityIdentifier("trashEmptyLabel")
        } else if let countText = presentation.countText {
            (Text(countText).bold() + Text("  지운 날 최신순").foregroundColor(palette.inkMuted))
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(palette.ink)
                .padding(.bottom, 4)
            ForEach(presentation.rows) { row in
                GrepSettingRow(
                    label: "\(row.number)  \(row.title)",
                    sub: row.meta,
                    actionLabel: "되살리기",
                    actionKind: .secondary,
                    isActionDisabled: presentation.isBusy,
                    actionAccessibilityId: "trashRevive_\(row.number)"
                ) {
                    onRevive(row.number)
                }
            }
            if presentation.hasMore {
                GrepUIButton(presentation.isLoadingMore ? "불러오는 중…" : "더 보기", kind: .ghost, isDisabled: presentation.isLoadingMore) {
                    onLoadMore()
                }
                .accessibilityIdentifier("trashMoreButton")
            }
            GrepUIButton("휴지통 비우기", kind: .danger, size: .lg, fullWidth: true, isDisabled: presentation.isBusy) {
                showEmptySheet = true
            }
            .padding(.top, 16)
            .accessibilityIdentifier("trashEmptyButton")
        }
    }

    private func noticeLine(_ notice: TrashNotice) -> some View {
        let (symbol, color): (String, Color) = switch notice.tone {
        case .ok: ("✓", palette.prompt)
        case .info: ("·", palette.inkMuted)
        case .error: ("✗", palette.danger)
        }
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(symbol)
                .bold()
                .foregroundStyle(color)
                .accessibilityHidden(true)
            (Text(notice.boldPrefix).bold().foregroundColor(color) + Text(notice.body))
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 14, design: .monospaced))
        .frame(minHeight: 32, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("trashNotice")
    }
}
