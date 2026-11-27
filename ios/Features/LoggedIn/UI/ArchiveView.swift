import SwiftUI

/// 보관함 탭 순수 SwiftUI 뷰(MOB-001, 시안 `MobileArchive.dc.html` · `MList.dc.html` · `MPickBar.dc.html`).
public struct ArchiveView: View {
    let presentation: ArchivePresentation
    let scrollToTopTrigger: Int
    let onRefresh: @MainActor () async -> Void
    let onLoadMore: () -> Void
    let onTogglePick: ((Int) -> Void)?
    let onMovePickedToTerminal: (() -> Void)?
    let onClearPicked: (() -> Void)?

    public init(
        presentation: ArchivePresentation,
        scrollToTopTrigger: Int = 0,
        onRefresh: @escaping @MainActor () async -> Void,
        onLoadMore: @escaping () -> Void,
        onTogglePick: ((Int) -> Void)? = nil,
        onMovePickedToTerminal: (() -> Void)? = nil,
        onClearPicked: (() -> Void)? = nil
    ) {
        self.presentation = presentation
        self.scrollToTopTrigger = scrollToTopTrigger
        self.onRefresh = onRefresh
        self.onLoadMore = onLoadMore
        self.onTogglePick = onTogglePick
        self.onMovePickedToTerminal = onMovePickedToTerminal
        self.onClearPicked = onClearPicked
    }

    private let palette = LoggedInPalette.dark

    public var body: some View {
        VStack(spacing: 0) {
            GrepTopBar(
                title: "보관함",
                status: presentation.statusText,
                plain: true,
                statusAccessibilityId: "archiveStatusText"
            )
            contentBody
            if presentation.pickedCount > 0 {
                GrepPickBar(
                    count: presentation.pickedCount,
                    summary: presentation.pickedSummary,
                    onMoveToTerminal: { onMovePickedToTerminal?() },
                    onClear: { onClearPicked?() }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.surface.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var contentBody: some View {
        if presentation.isLoading && presentation.items.isEmpty {
            loadingView
        } else if let errorMessage = presentation.errorMessage, presentation.items.isEmpty {
            errorView(message: errorMessage)
        } else if presentation.items.isEmpty {
            emptyView
        } else {
            itemListView
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .tint(palette.prompt)
            Text("· 자료 불러오는 중")
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(palette.inkMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("archiveLoadingView")
    }

    private func errorView(message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("✗")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.danger)
                Text("불러오기 안 됨: \(message)")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(palette.ink)
            }
            GrepUIButton("다시 시도", kind: .secondary, size: .md) {
                Task { await onRefresh() }
            }
            .accessibilityIdentifier("archiveRetryButton")
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityIdentifier("archiveErrorView")
    }

    private var emptyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("·")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.command)
                    Text("자료 0건")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.ink)
                }
                Text("터미널 탭에서 링크나 글을 저장하면 여기에 최근 순으로 모입니다.")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                GrepUIButton("새로고침", kind: .secondary, size: .md) {
                    Task { await onRefresh() }
                }
                .accessibilityIdentifier("archiveRefreshButton")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .refreshable {
            await onRefresh()
        }
        .accessibilityIdentifier("archiveEmptyView")
    }

    private var itemListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    Color.clear.frame(height: 1).id("archiveTop")

                    ForEach(presentation.items) { item in
                        mobileListRow(item)
                    }

                    Text("· 왼쪽 칸: 고르기")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(palette.inkMuted)
                        .padding(.top, 10)

                    if let errorMessage = presentation.errorMessage {
                        HStack(spacing: 8) {
                            Text("✗ 불러오기 안 됨: \(errorMessage)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(palette.danger)
                            Spacer()
                            GrepUIButton("다시 시도", kind: .ghost, size: .sm) {
                                onLoadMore()
                            }
                        }
                        .padding(.top, 8)
                    }

                    if presentation.isLoadingMore {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                                .tint(palette.prompt)
                            Text("· 더 불러오는 중")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(palette.inkMuted)
                        }
                        .frame(minHeight: 44, alignment: .leading)
                    } else if presentation.hasMore {
                        Button(action: onLoadMore) {
                            HStack(spacing: 4) {
                                Text("→")
                                    .foregroundStyle(palette.inkMuted)
                                Text("더 보기")
                                    .underline()
                                    .foregroundStyle(palette.command)
                            }
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("archiveMoreButton")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .refreshable {
                await onRefresh()
            }
            .onChange(of: scrollToTopTrigger) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("archiveTop", anchor: .top)
                }
            }
            .accessibilityIdentifier("archiveItemList")
        }
    }

    /// 시안 `MList.dc.html`: 왼쪽 44pt 체크박스 칸 + 번호(4ch) + 제목·메타 두 줄.
    private func mobileListRow(_ item: ArchiveItemRow) -> some View {
        HStack(alignment: .center, spacing: 0) {
            Button {
                onTogglePick?(item.number)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(item.isPicked ? palette.prompt : Color.clear)
                        .frame(width: 20, height: 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(item.isPicked ? palette.prompt : palette.line, lineWidth: 1.5)
                        )
                    if item.isPicked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(palette.surface)
                    }
                }
                .frame(width: 44, height: 56)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.isPicked ? "선택 해제" : "고르기"): \(item.title)")
            .accessibilityIdentifier("archiveCheck_\(item.number)")

            HStack(alignment: .center, spacing: 8) {
                Text(item.isPicked ? "▸\(item.number)" : "\(item.number)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(item.isPicked ? palette.command : palette.inkMuted)
                    .frame(minWidth: 36, alignment: .trailing)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(palette.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    rowMetaLine(item)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 6)
            .padding(.trailing, 8)
            .frame(minHeight: 56)
        }
        .background(item.isPicked ? palette.select : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .accessibilityIdentifier("archiveItem_\(item.number)")
    }

    private func rowMetaLine(_ item: ArchiveItemRow) -> some View {
        HStack(spacing: 0) {
            if !item.meta.isEmpty {
                Text(item.meta)
                    .foregroundStyle(palette.inkMuted)
            }
            if let summary = item.summary, item.summaryIsWarning {
                Text(item.meta.isEmpty ? summary : " · \(summary)")
                    .foregroundStyle(palette.notice)
            } else if let summary = item.summary, summary.hasPrefix("· 요약 생성 중") {
                Text(item.meta.isEmpty ? "요약 생성 중" : " · 요약 생성 중")
                    .foregroundStyle(palette.inkMuted)
            } else if !item.tags.isEmpty {
                Text(" · " + item.tags.map { "#\($0)" }.joined(separator: " "))
                    .foregroundStyle(palette.inkMuted)
            }
        }
        .font(.system(size: 12, design: .monospaced))
        .lineLimit(1)
        .truncationMode(.tail)
    }
}
