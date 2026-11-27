import GrepCore

// 계약 2(#157) 묶음·자세히 보기·찾아두기·연결 줄에 담는 값. 이름은 `web/support/view-state.ts`와 같다.

/// 자세히 보기(api `ItemDetail`, ARC-011 규칙 6). 차례와 문구는 뷰가 정책대로 그린다.
public struct ItemDetail: Equatable, Sendable, Codable {
    public let item: ItemSummary
    /// 넘기기용 요약 또는 직접 고친 요약. 이름표는 `item.summarySource`.
    public let handoffSummary: String?
    public let allTags: [String]
    /// 든 묶음 이름. 비면 `묶음  없음`.
    public let bundles: [String]
    public let bodyLength: Int
    /// 펼치기용 본문(앞 2만 자). nil이면 `· 본문 없음: <이유>`(item.blockedReason·status).
    public let body: String?
    public let bodyFromImage: Bool
    /// 파일 원본 서명 URL(10분). `원본 열기`.
    public let originalUrl: String?
    /// 이미지 미리보기 서명 URL.
    public let previewUrl: String?

    public init(
        item: ItemSummary,
        handoffSummary: String?,
        allTags: [String],
        bundles: [String],
        bodyLength: Int,
        body: String?,
        bodyFromImage: Bool,
        originalUrl: String?,
        previewUrl: String?
    ) {
        self.item = item
        self.handoffSummary = handoffSummary
        self.allTags = allTags
        self.bundles = bundles
        self.bodyLength = bodyLength
        self.body = body
        self.bodyFromImage = bodyFromImage
        self.originalUrl = originalUrl
        self.previewUrl = previewUrl
    }
}

/// `묶음` 목록 한 줄(ARC-003).
public struct BundleEntry: Equatable, Sendable, Codable {
    public let name: String
    public let count: Int

    public init(name: String, count: Int) {
        self.name = name
        self.count = count
    }
}

/// `찾아두기` 목록 한 줄(ARC-012).
public struct SavedSearchEntry: Equatable, Sendable, Codable {
    public let query: String
    public let count: Int

    public init(query: String, count: Int) {
        self.query = query
        self.count = count
    }
}

/// `<번호>  <AI 도구>  연결 <날짜>  읽음 <날짜>`(ACC-002). 날짜는 RFC 3339, `lastReadAt`은 없으면 nil.
public struct ConnectionEntry: Equatable, Sendable, Codable {
    public let number: Int
    public let client: String
    public let connectedAt: String
    public let lastReadAt: String?

    public init(number: Int, client: String, connectedAt: String, lastReadAt: String?) {
        self.number = number
        self.client = client
        self.connectedAt = connectedAt
        self.lastReadAt = lastReadAt
    }
}

/// `✗ 묶음 이름: …` 이유(ARC-003).
public enum BundleNameProblem: String, Equatable, Sendable, Codable {
    /// `✗ 묶음 이름: 띄어쓰기 없이 1~20자 …`
    case format
    /// `✗ 묶음 이름: 숫자만 · #시작 · 빼기 · 지우기 불가`
    case reserved
}

/// `! 연결 끊김: <AI 도구> (<이유>)` 이유(ACC-002 규칙 11).
public enum ConnectionEndReason: String, Equatable, Sendable, Codable {
    case expired
    case revoked
}
