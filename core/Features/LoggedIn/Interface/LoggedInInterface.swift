import GrepCore
import RIBs

/// 터미널 화면에 그릴 값 전체. 문구는 담지 않는다(플랫폼 뷰가 정책 원문으로 바꾼다).
public struct LoggedInViewState: Equatable, Sendable {
    /// 출력 한 줄. #31에서 쓰는 것만 둔다. 다른 이슈가 case를 더한다.
    public enum Line: Equatable, Sendable {
        /// 사용자가 친 명령 줄(`그렙 ~ $ <text>`).
        case prompt(String)
        /// `✗ 없는 명령: <name>`
        case unknownCommand(String)
        /// 빠진 인자(`✗ 검색어 없음  예: …` 등). 문구는 명령마다 뷰가 정책 원문으로 고른다.
        case missingArgument(CommandName)
        /// `찾기 #`처럼 `#` 뒤가 비었다. `✗ 태그 없음  예: 찾기 #결제`(ARC-002).
        case missingTag
        /// `✓ 저장됨  <제목> (<출처>)` 뒤에 `· 요약 생성 중`(ARC-005). 글이면 `✓ 저장됨 (글)  <제목>`.
        case saved(ItemSummary)
        /// `! 이미 저장됨 → N번 (새로 만들지 않음)` 뒤에 그 자료 한 줄과 `→ 고르기 N`(COM-001).
        case alreadySaved(ItemSummary)
        /// `! 휴지통에 있음 → N번. 되살리기 N`(COM-001 규칙 7, ARC-008).
        case inTrash(number: Int)
        /// `✗ 저장 안 됨: <이유>  입력은 남겨 둠`(ARC-005), 파일이면 COM-004 문구.
        case saveFailed(SaveFailure)
        /// `최근` 목록. 자료마다 두 줄(번호·제목·출처·저장 시각 / 흐린 요약, 태그 앞 3개).
        /// `hasMore`면 `→ 더 보기`. 처리 상태가 바뀌면 코어가 같은 줄의 자료 값을 바꾼다(ARC-005 규칙 10).
        /// 자료를 든 다른 줄(`saved`·`alreadySaved`·`searchResult`·`noResults`)도 같이 바꾼다.
        case recentList(items: [ItemSummary], hasMore: Bool)
        /// `찾기` 결과. 머리줄 `4건` 또는 `23건 중 10건`(total과 items 수).
        case searchResult(query: SearchQuery, total: Int, items: [ItemSummary], hasMore: Bool)
        /// `· 0건: "<검색어>"` 뒤에 `· 최근 저장 3건 (검색 결과 아님)` 머리줄과 그 자료들(commands 6절).
        case noResults(query: SearchQuery, recent: [ItemSummary])
        /// `✓ 선택 N건  <제목> · <제목>` 뒤에 `→ 넘기기 또는 묶음 <이름>`.
        case picked([ItemRef])
        /// `✗ 없는 번호: <번호>`(여러 개면 쉼표, ARC-001 규칙 10).
        case notFound(numbers: [Int])
        /// `✗ 잘못된 번호: <입력>  예: 고르기 131 140`(ARC-001 규칙 11).
        case invalidNumber(String)
        /// `✓ 복사됨  N건 · M자 (제목·출처·저장 시각·요약)`, 자료 줄, `· 미리보기: 펼치기`, 클립보드 안내.
        /// 요약 없는 자료가 있으면 `! 요약 없음 N건`(handoff-format 3절).
        case handedOff(HandoffResult)
        /// `✗ 복사 안 됨: <이유>  선택은 남겨 둠` 다음 줄 `→ 넘기기`(COM-008).
        /// `clipboardDenied`면 `preview`(넘길 글 전체)를 펼쳐 보이고 `→ 직접 복사: Ctrl+C · 다시: 넘기기`.
        case handoffFailed(reason: CommandFailure, preview: String?)
        /// `찾기`·`최근`·`고르기` 실패: `✗ <명령> 안 됨: <이유>` 다음 줄 `→ 다시: <retry>`(COM-010).
        case commandFailed(command: CommandName, reason: CommandFailure, retry: String)
        /// `! N건: 바로 복사 안 함 (5건 초과)` 뒤에 낱말 선택지. 10건 이하면 `전부`만, 넘으면 `앞10`·`전부`(COM-008).
        case handoffConfirm(total: Int)
        /// `· 취소됨`(COM-007).
        case cancelled
        /// 자료 0건 첫 화면: 한 문장, 표어, `· 자료 0건`, 샘플 안내, `· 명령 전체: 도움말`(commands 6절).
        case welcome
        /// `도움말` 화면(commands 2절).
        case guide
        /// `설명 <명령>`(commands 3절).
        case about(CommandName)
        /// `✓ 연결됨`(COM-010).
        case reconnected
    }

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

    public init(
        itemCount: Int? = nil,
        lines: [Line] = [],
        input: String = "",
        selection: [ItemRef] = [],
        processingCount: Int = 0,
        isOffline: Bool = false
    ) {
        self.itemCount = itemCount
        self.lines = lines
        self.input = input
        self.selection = selection
        self.processingCount = processingCount
        self.isOffline = isOffline
    }
}

/// 자료를 가리키는 최소 값. 선택 줄·넘긴 자료 줄에 쓴다.
public struct ItemRef: Equatable, Sendable {
    public let number: Int
    public let title: String

    public init(number: Int, title: String) {
        self.number = number
        self.title = title
    }
}

/// `찾기`의 조건. 태그는 `#` 없이(ARC-002 규칙 5~8).
public struct SearchQuery: Equatable, Sendable {
    /// 사용자가 친 검색어 그대로. `· 0건: "<text>"`에 쓴다.
    public let text: String
    public let words: String
    public let tags: [String]

    public init(text: String, words: String, tags: [String]) {
        self.text = text
        self.words = words
        self.tags = tags
    }
}

/// 서버 `POST /handoff` 결과(api/openapi.yaml `Handoff`).
public struct HandoffResult: Equatable, Sendable {
    public let items: [ItemRef]
    /// 줄바꿈을 포함한 글자 수.
    public let charCount: Int
    public let missingSummaryCount: Int
    /// 클립보드에 넣은 글 전체. `펼치기`로 보인다.
    public let text: String

    public init(items: [ItemRef], charCount: Int, missingSummaryCount: Int, text: String) {
        self.items = items
        self.charCount = charCount
        self.missingSummaryCount = missingSummaryCount
        self.text = text
    }
}

/// 명령 실패 이유(COM-008, COM-010).
public enum CommandFailure: Equatable, Sendable {
    /// `연결 끊김`
    case disconnected
    /// `응답 없음`
    case timedOut
    /// `서버 오류`
    case serverError
    /// `클립보드 거부`(넘기기만)
    case clipboardDenied
}

/// 뷰 → 코어.
public enum LoggedInViewAction: Equatable, Sendable {
    /// 입력줄이 바뀌었다. 코어가 만료 때 보존할 줄을 알기 위해 받는다.
    case inputChanged(String)
    /// 엔터.
    case submitted(String)
    /// 입력줄에 링크·글을 붙여 넣었다. 붙여 넣기만 해도 저장한다(commands 3절 담기).
    case pasted(String)
    /// 파일을 끌어다 놓았다. 바이트는 `FilePort`가 `DroppedFile.id`로 올린다.
    case filesDropped([DroppedFile])
    /// 목록 맨 아래 `→ 더 보기`를 눌렀다.
    case moreRequested
}

@MainActor
public protocol LoggedInPresentableListener: AnyObject {
    func handle(_ action: LoggedInViewAction)
}

@MainActor
public protocol LoggedInPresentable: Presentable {
    var listener: (any LoggedInPresentableListener)? { get set }
    func render(_ state: LoggedInViewState)
}

@MainActor
public protocol LoggedInViewControllable: ViewControllable {}

@MainActor
public protocol LoggedInViewContract: LoggedInPresentable, LoggedInViewControllable {}

@MainActor
public protocol LoggedInViewFactory: AnyObject {
    func makeLoggedInView() -> any LoggedInViewContract
}

/// 데모 범위 명령(commands 2절). 한글·영문 이름은 코어가 해석한다.
public enum CommandName: Equatable, Sendable, CaseIterable {
    /// `담기`(keep)
    case keep
    /// `최근`(recent)
    case recent
    /// `찾기`(seek)
    case seek
    /// `고르기`(pick)
    case pick
    /// `넘기기`(handoff)
    case handoff
    /// `도움말`(guide)
    case guide
    /// `설명`(about)
    case about
    /// `로그아웃`(signout)
    case signOut
}

/// 저장 실패 이유.
public enum SaveFailure: Equatable, Sendable {
    /// `연결 끊김`(COM-010)
    case disconnected
    /// `응답 없음`(COM-010)
    case timedOut
    /// `서버 오류`
    case serverError
    /// `✗ 저장 안 됨: 받지 않는 형식 (.<확장자>)`(COM-004)
    case unsupportedFormat(fileExtension: String)
    /// `✗ 저장 안 됨: 20MB 넘음 (<파일 이름> · <크기>)`(COM-004 규칙 8). 크기는 바이트.
    case tooLarge(fileName: String, bytes: Int)
}
