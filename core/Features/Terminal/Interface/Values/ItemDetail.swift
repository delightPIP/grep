import GrepCore

// 계약 2(#157) 묶음·자세히 보기·찾아두기·연결 줄에 담는 값. 이름은 `web/support/view-state.ts`와 같다.

/// 자세히 보기(api `ItemDetail`, ARC-011 규칙 6). 차례와 문구는 뷰가 정책대로 그린다.
public struct ItemDetail: Equatable, Sendable, Codable {
    public let item: ItemSummary
    /// 링크의 원래 주소. 출처를 누르면 새 탭으로 연다(ARC-011 규칙 6-2). 링크가 아니면 nil.
    public let url: String?
    /// 넘기기용 요약 또는 직접 고친 요약. 이름표는 `item.summarySource`.
    public let handoffSummary: String?
    public let allTags: [String]
    /// 든 묶음 이름. 비면 `묶음  없음`.
    public let bundles: [String]
    /// 본문 글자 수. `body`가 nil이면 nil.
    public let bodyLength: Int?
    /// 펼치기용 본문(앞 2만 자). nil이면 `· 본문 없음: <이유>`(item.blockedReason·status).
    public let body: String?
    public let bodyFromImage: Bool
    /// 파일 원본 서명 URL(10분). `원본 열기`.
    public let originalUrl: String?
    /// 이미지 미리보기 서명 URL.
    public let previewUrl: String?

    public init(
        item: ItemSummary,
        url: String?,
        handoffSummary: String?,
        allTags: [String],
        bundles: [String],
        bodyLength: Int?,
        body: String?,
        bodyFromImage: Bool,
        originalUrl: String?,
        previewUrl: String?
    ) {
        self.item = item
        self.url = url
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
