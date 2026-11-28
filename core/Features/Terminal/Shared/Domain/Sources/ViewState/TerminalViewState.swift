import GrepDomain

/// 터미널 화면에 그릴 값 전체. 문구는 담지 않는다(플랫폼 뷰가 정책 원문으로 바꾼다).
public struct TerminalViewState: Equatable, Sendable {
    /// 상태줄 `자료 N`. 서버 `GET /me`의 itemCount. 받기 전이면 nil.
    public var itemCount: Int?
    public var lines: [Line]
    /// 입력줄 내용. 로그인 만료 뒤 다시 로그인하면 되살린 값이 들어온다(ACC-001 규칙 7).
    public var input: String
    /// 고른 자료, 고른 순서. 상태줄 `선택 N`과 입력줄 위 `선택 2  <제목> · <제목>` 줄, 목록 행의 `▸`.
    public var selection: [ItemRef]
    /// 상태줄 `요약 생성 중 N`. 0이면 칸을 숨긴다.
    public var processingCount: Int
    /// 상태줄 `연결 끊김` 칸(COM-010).
    public var isOffline: Bool
    /// #93 `고치기` 편집 중이면 그 자료. 없으면 nil.
    public var revising: Revising?
    /// #175 땅굴 두더지가 지금 할 동작. 아직 없으면 nil.
    public var mole: Mole?

    public init(
        itemCount: Int? = nil,
        lines: [Line] = [],
        input: String = "",
        selection: [ItemRef] = [],
        processingCount: Int = 0,
        isOffline: Bool = false,
        revising: Revising? = nil,
        mole: Mole? = nil
    ) {
        self.itemCount = itemCount
        self.lines = lines
        self.input = input
        self.selection = selection
        self.processingCount = processingCount
        self.isOffline = isOffline
        self.revising = revising
        self.mole = mole
    }
}
