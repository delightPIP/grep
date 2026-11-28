/// 자료 한 건의 목록용 값(api/openapi.yaml `ItemSummary`). 자료는 사용자별 번호로만 가리킨다(ARC-001).
public struct ItemSummary: Equatable, Sendable, Codable {
    /// ARC-001 자료 번호. 화면에 숫자만 쓴다.
    public let number: Int
    public let kind: ItemKind
    /// 링크는 페이지 제목, 글은 첫 줄 24자까지, 파일은 파일 이름.
    public let title: String
    /// 링크는 호스트, 파일은 형식. 없을 수 있다.
    public let source: String?
    public let status: ItemStatus
    /// `status == .blocked`일 때 이유.
    public let blockedReason: BlockedReason?
    /// 흐린 한 줄 요약. 직접 고친 요약이 있으면 그것. 처리 전·실패면 nil.
    public let listSummary: String?
    /// 요약 출처(ARC-004 규칙 5). 요약이 없으면 nil.
    public let summarySource: SummarySource?
    /// 일부만 읽었을 때 요약 끝에 붙일 말(ARC-004 규칙 8).
    public let partialNote: String?
    /// 자동 태그, `#` 없이(ARC-002). 목록은 앞 3개만 보인다.
    public let tags: [String]
    /// 찾기 결과에서 일치한 곳. 찾기가 아니면 nil.
    public let matchedIn: MatchLocation?
    /// 저장 시각. RFC 3339 문자열 그대로 둔다. 한국 시간으로 바꾸는 것은 뷰가 한다(ARC-004 규칙 7).
    public let savedAt: String

    public init(
        number: Int,
        kind: ItemKind,
        title: String,
        source: String?,
        status: ItemStatus,
        blockedReason: BlockedReason? = nil,
        listSummary: String? = nil,
        summarySource: SummarySource? = nil,
        partialNote: String? = nil,
        tags: [String],
        matchedIn: MatchLocation? = nil,
        savedAt: String
    ) {
        self.number = number
        self.kind = kind
        self.title = title
        self.source = source
        self.status = status
        self.blockedReason = blockedReason
        self.listSummary = listSummary
        self.summarySource = summarySource
        self.partialNote = partialNote
        self.tags = tags
        self.matchedIn = matchedIn
        self.savedAt = savedAt
    }
}

public enum ItemKind: String, Equatable, Sendable, Codable {
    case link
    case text
    case file
}

/// ARC-005 처리 상태. 이 다섯 가지뿐이다.
public enum ItemStatus: String, Equatable, Sendable, Codable {
    case received
    case processing
    case ready
    case blocked
    case failed
}

/// `! 본문 못 가져옴: <이유>`. ARC-005 세 가지와 COM-004 규칙 6 두 가지.
public enum BlockedReason: String, Equatable, Sendable, Codable {
    /// `로그인 필요`
    case loginRequired = "login_required"
    /// `접근 거부`
    case accessDenied = "access_denied"
    /// `열지 않는 주소`(ARC-006)
    case disallowedURL = "disallowed_url"
    /// `암호 걸린 PDF`
    case encrypted
    /// `글자 없음`
    case noText = "no_text"
}

/// 찾기에서 일치한 곳. 요약 줄 끝에 흐리게 쓴다(commands 6절 목록 꼬리표, 예: `이미지 속 글자`).
public enum MatchLocation: String, Equatable, Sendable, Codable {
    case title
    case source
    case summary
    case body
    case imageText
    case tag
}

/// ARC-004 규칙 5 출처 값.
public enum SummarySource: String, Equatable, Sendable, Codable {
    case ai
    case user
}
