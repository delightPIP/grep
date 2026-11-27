import FeatureLoggedInUI
import Foundation
import GrepCore
import Observation

/// 설정 › 휴지통 화면의 상태와 불러오기·되살리기·비우기(ARC-008 규칙 4·5·6·10·11, 시안 M11).
/// 문구는 터미널 `휴지통`·`되살리기`·`휴지통 비우기`의 정책 문구와 같다.
@MainActor @Observable
public final class TrashScreenModel {
    public static let defaultPageLimit = 20

    public private(set) var presentation = TrashPresentation()

    @ObservationIgnored private let client: any TrashClient
    @ObservationIgnored private let pageLimit: Int
    @ObservationIgnored private let onSessionExpired: (@MainActor () -> Void)?
    @ObservationIgnored private var entries: [TrashListEntry] = []
    @ObservationIgnored private var nextCursor: String?

    public init(
        client: any TrashClient,
        pageLimit: Int = TrashScreenModel.defaultPageLimit,
        onSessionExpired: (@MainActor () -> Void)? = nil
    ) {
        self.client = client
        self.pageLimit = pageLimit
        self.onSessionExpired = onSessionExpired
    }

    /// 화면을 열 때마다 처음 쪽부터 다시 받는다. 터미널에서 버리거나 되살린 것이 바로 보이게 한다.
    public func refresh() async {
        guard !presentation.isLoading else { return }
        presentation.isLoading = true
        presentation.notice = nil
        let outcome = await client.loadPage(limit: pageLimit, cursor: nil)
        presentation.isLoading = false
        switch outcome {
        case .page(let total, let page, let cursor):
            entries = page
            nextCursor = cursor
            rebuild(total: total)
        case .sessionExpired:
            onSessionExpired?()
        case .failed(let reason):
            presentation.notice = Self.failure("휴지통", reason)
        case .cancelled:
            break
        }
    }

    public func loadMore() async {
        guard let cursor = nextCursor, !presentation.isLoading, !presentation.isLoadingMore else { return }
        presentation.isLoadingMore = true
        let outcome = await client.loadPage(limit: pageLimit, cursor: cursor)
        presentation.isLoadingMore = false
        switch outcome {
        case .page(let total, let page, let next):
            let known = Set(entries.map(\.item.number))
            entries += page.filter { !known.contains($0.item.number) }
            nextCursor = next
            rebuild(total: total)
        case .sessionExpired:
            onSessionExpired?()
        case .failed(let reason):
            presentation.notice = Self.failure("휴지통", reason)
        case .cancelled:
            break
        }
    }

    /// `되살리기 <번호>`와 같다. 번호는 바뀌지 않고 원래 묶음에 다시 보인다(ARC-008 규칙 3·4).
    public func revive(number: Int) async {
        guard !presentation.isBusy else { return }
        presentation.isBusy = true
        let outcome = await client.restore(numbers: [number])
        presentation.isBusy = false
        switch outcome {
        case .restored(let numbers):
            remove(numbers, notice: TrashNotice(tone: .ok, boldPrefix: "되살림 \(numbers.count)건"))
        case .notFound(let numbers):
            // 30일이 지나 영구 삭제된 번호다. 목록에서도 뺀다(ARC-001).
            let list = numbers.map(String.init).joined(separator: ", ")
            remove(numbers, notice: TrashNotice(tone: .error, boldPrefix: "없는 번호:", body: " \(list)"))
        case .sessionExpired:
            onSessionExpired?()
        case .failed(let reason):
            presentation.notice = Self.failure("되살리기", reason)
        case .cancelled:
            break
        }
    }

    /// 확인 시트에서 `비우기`를 누른 뒤에 부른다(ARC-008 규칙 6).
    public func empty() async {
        guard !presentation.isBusy else { return }
        presentation.isBusy = true
        let outcome = await client.empty()
        presentation.isBusy = false
        switch outcome {
        case .emptied(let count):
            entries = []
            nextCursor = nil
            rebuild(total: 0)
            // 빈 휴지통을 비우면 `0건 영구 삭제` 대신 비어 있다고만 둔다(웹과 같음).
            presentation.notice = count > 0 ? TrashNotice(tone: .ok, boldPrefix: "비움", body: "  \(count)건 영구 삭제") : nil
        case .sessionExpired:
            onSessionExpired?()
        case .failed(let reason):
            presentation.notice = Self.failure("휴지통 비우기", reason)
        case .cancelled:
            break
        }
    }

    private func remove(_ numbers: [Int], notice: TrashNotice) {
        let removed = Set(numbers)
        let before = entries.count
        entries.removeAll { removed.contains($0.item.number) }
        let total = max(0, (presentation.total ?? before) - (before - entries.count))
        rebuild(total: total)
        presentation.notice = notice
    }

    private func rebuild(total: Int) {
        presentation.total = total
        presentation.rows = entries.map(Self.mapRow)
        presentation.hasMore = nextCursor != nil
    }

    /// 휴지통 행. 시각 칸에 영구 삭제까지 남은 날(ARC-008 규칙 10). 터미널 `휴지통` 행과 같다.
    static func mapRow(_ entry: TrashListEntry) -> TrashRowPresentation {
        let item = entry.item
        let title = item.kind == .text ? ArchiveItemMapper.textTitle(item.title) : item.title
        let meta = [item.source, "\(entry.daysLeft)일 남음"].compactMap { $0 }.filter { !$0.isEmpty }
        return TrashRowPresentation(number: item.number, title: title, meta: meta.joined(separator: " · "))
    }

    /// 터미널의 명령 실패 줄과 같은 꼴(`<명령> 안 됨: <이유>`, COM-010).
    private static func failure(_ command: String, _ reason: ArchiveLoadFailure) -> TrashNotice {
        TrashNotice(tone: .error, boldPrefix: "\(command) 안 됨:", body: " \(ArchiveItemMapper.errorMessage(reason))")
    }
}
