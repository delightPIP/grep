import Foundation

/// 휴지통 화면 한 줄(시안 M11 ①). `meta` 끝은 영구 삭제까지 남은 날(ARC-008 규칙 10).
public struct TrashRowPresentation: Equatable, Sendable, Identifiable {
    public var id: Int { number }
    public let number: Int
    public let title: String
    public let meta: String

    public init(number: Int, title: String, meta: String) {
        self.number = number
        self.title = title
        self.meta = meta
    }
}

/// 되살리기·비우기 뒤 화면 위에 찍는 한 줄(ARC-008 사용자 문구).
public struct TrashNotice: Equatable, Sendable {
    public enum Tone: Equatable, Sendable {
        case ok
        case info
        case error
    }

    public let tone: Tone
    public let boldPrefix: String
    public let body: String

    public init(tone: Tone, boldPrefix: String, body: String = "") {
        self.tone = tone
        self.boldPrefix = boldPrefix
        self.body = body
    }
}

/// 설정 › 휴지통 순수 뷰가 그리는 값 전체(ARC-008 규칙 5·6·10·11, 시안 `MobileTrash.dc.html` M11).
public struct TrashPresentation: Equatable, Sendable {
    /// 서버가 알려 준 휴지통 전체 건수. 처음 불러오기 전에는 nil.
    public var total: Int?
    public var rows: [TrashRowPresentation]
    public var hasMore: Bool
    public var isLoading: Bool
    public var isLoadingMore: Bool
    /// 되살리기·비우기를 보내는 중이면 true. 그동안 버튼을 막는다.
    public var isBusy: Bool
    public var notice: TrashNotice?

    public init(
        total: Int? = nil,
        rows: [TrashRowPresentation] = [],
        hasMore: Bool = false,
        isLoading: Bool = false,
        isLoadingMore: Bool = false,
        isBusy: Bool = false,
        notice: TrashNotice? = nil
    ) {
        self.total = total
        self.rows = rows
        self.hasMore = hasMore
        self.isLoading = isLoading
        self.isLoadingMore = isLoadingMore
        self.isBusy = isBusy
        self.notice = notice
    }

    /// 머리 줄 건수. 다음 쪽이 남았으면 `12건 중 3건`(터미널 `휴지통`과 같음).
    public var countText: String? {
        guard let total, total > 0 else { return nil }
        return rows.count < total ? "\(total)건 중 \(rows.count)건" : "\(total)건"
    }

    public var isEmpty: Bool { total == 0 }

    /// 비우기 확인 시트 제목(ARC-008 사용자 문구).
    public var emptyConfirmTitle: String {
        "비우기? \(total ?? rows.count)건 (되돌릴 수 없음)"
    }
}
