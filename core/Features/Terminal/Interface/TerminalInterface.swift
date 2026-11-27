import GrepCore
import RIBs

/// 터미널 화면에 그릴 값 전체. 문구는 담지 않는다(플랫폼 뷰가 정책 원문으로 바꾼다).
public struct TerminalViewState: Equatable, Sendable {
    /// 출력 한 줄. #31에서 쓰는 것만 둔다. 다른 이슈가 case를 더한다.
    public enum Line: Equatable, Sendable {
        /// 사용자가 친 명령 줄(`그렙 ~ $ <text>`).
        case prompt(String)
        /// `✗ 없는 명령: <name>` (#118 오타 제안이 있으면 `suggestion`에 고친 입력 전체)
        case unknownCommand(String, suggestion: String? = nil)
        /// 빠진 인자(`✗ 검색어 없음  예: …` 등). 문구는 명령마다 뷰가 정책 원문으로 고른다.
        /// `sub`는 하위 명령(`고르기 빼기`면 `.unpick`, 예시 `예: 고르기 빼기 131`, #154).
        case missingArgument(CommandName, sub: MissingArgumentSub? = nil)
        /// `찾기 #`처럼 `#` 뒤가 비었다. `✗ 태그 없음  예: 찾기 #결제`(ARC-002).
        case missingTag
        /// `✓ 저장됨  <제목> (<출처>)` 뒤에 `· 요약 생성 중`(ARC-005). 글이면 `✓ 저장됨 (글)  <제목>`.
        case saved(ItemSummary)
        /// `! 이미 저장됨 → N번 (새로 만들지 않음)` 뒤에 그 자료 한 줄과 `→ 고르기 N`(COM-001).
        case alreadySaved(ItemSummary)
        /// `! 휴지통에 있음 → N번. 되살리기 N`(COM-001 규칙 7, ARC-008).
        case inTrash(number: Int)
        /// `✗ 저장 안 됨: <이유>`(ARC-005), 파일이면 COM-004 문구. 뒤에 붙는 말은 `SaveRecovery`가 정한다.
        case saveFailed(SaveFailure, SaveRecovery)
        /// `최근` 목록. 자료마다 두 줄(번호·제목·출처·저장 시각 / 흐린 요약, 태그 앞 3개).
        /// `hasMore`면 `→ 더 보기`. 처리 상태가 바뀌면 코어가 같은 줄의 자료 값을 바꾼다(ARC-005 규칙 10).
        /// 자료를 든 다른 줄(`saved`·`alreadySaved`·`searchResult`·`noResults`)도 같이 바꾼다.
        case recentList(items: [ItemSummary], hasMore: Bool, total: Int? = nil, period: Period? = nil)
        /// `찾기` 결과. 머리줄 `4건` 또는 `23건 중 10건`(total과 items 수).
        /// `isSavedSearch`가 false·nil이면 뷰가 `찾아두기 <검색어>` 칩을 둔다(ARC-012 규칙 9, 계약 2).
        case searchResult(
            query: SearchQuery,
            total: Int,
            items: [ItemSummary],
            hasMore: Bool,
            period: Period? = nil,
            isSavedSearch: Bool? = nil
        )
        /// `· 0건: "<검색어>"` 뒤에 `· 최근 저장 3건 (검색 결과 아님)` 머리줄과 그 자료들(commands 6절).
        case noResults(query: SearchQuery, recent: [ItemSummary], period: Period? = nil)
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
        // #93 정리(ARC-008)
        case dropConfirm(total: Int)
        case dropped([ItemRef])
        case revived([ItemRef])
        case binList(total: Int, items: [TrashEntry], hasMore: Bool)
        case binEmptyConfirm(total: Int)
        case binEmptied(count: Int)
        // #93 고치기(ARC-002·004)
        case revised(ItemSummary)
        case tagsRemoved(item: ItemSummary, tags: [String])
        // #93 샘플(ARC-010)
        case samplesSaved(firstNumber: Int, lastNumber: Int, items: [ItemSummary])
        // #108 고르기 빼기·비우기
        case unpicked(items: [ItemRef], remaining: Int)
        case pickCleared(count: Int)
        // #111 로그아웃 모든기기(ACC-002). connectionCount: 끊길 AI 도구 연결 수(`· AI 도구 연결 N개`). 모르면 nil
        case signOutEverywhereConfirm(connectionCount: Int?)
        // 계약 2 묶음(ARC-003)
        case bundleList([BundleEntry])
        case bundleAdded(name: String, count: Int, alreadyCount: Int)
        case bundleView(name: String, total: Int, items: [ItemSummary], hasMore: Bool)
        case bundleNotFound(name: String)
        case bundleUnpicked(name: String, remaining: Int)
        case notInBundle(name: String, numbers: [Int])
        case bundleDeleteConfirm(name: String, itemCount: Int)
        case bundleDeleted(name: String)
        case bundleNameInvalid(BundleNameProblem)
        /// `폴더`·`mkdir` 입력 안내(ARC-007 규칙 11).
        case folderHint
        // 계약 2 자세히 보기(ARC-011)
        case itemDetail(ItemDetail)
        /// `✗ 번호 하나만  예: <명령> 131`
        case oneNumberOnly(CommandName)
        // 계약 2 찾아두기(ARC-012). 결과 목록은 searchResult 줄이 이어서 온다
        case searchSaved(query: String, total: Int, already: Bool)
        case savedSearchList([SavedSearchEntry])
        /// `✗ 시점은 찾아두지 않음: <시점>` 다음 줄 `→ 찾아두기 <검색어>`
        case savedSearchPeriod(period: String, suggestion: String)
        case savedSearchTooLong
        case savedSearchDeleteConfirm(query: String)
        case savedSearchDeleted(query: String)
        case savedSearchNotFound(query: String)
        // 계약 2 AI 도구 연결(ACC-002)
        case connectionList(mcpUrl: String, connections: [ConnectionEntry])
        case disconnectConfirm(number: Int, client: String)
        case disconnected(client: String, already: Bool)
        case connectionNotFound(number: Int)
        /// 그렙을 열 때 한 번(ACC-002 규칙 11) `! 연결 끊김: <AI 도구> (<이유>)`
        case connectionEnded(client: String, reason: ConnectionEndReason)
        // 계약 2 북마크 가져오기(commands 6절)
        case importPrompt
        case importProgress(done: Int, total: Int)
        case importFinished(saved: Int, skipped: Int, failed: Int, overLimit: Int, failedUrls: [String])
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
    /// #93 `고치기` 편집 중이면 그 자료. 없으면 nil.
    public var revising: Revising?

    public init(
        itemCount: Int? = nil,
        lines: [Line] = [],
        input: String = "",
        selection: [ItemRef] = [],
        processingCount: Int = 0,
        isOffline: Bool = false,
        revising: Revising? = nil
    ) {
        self.itemCount = itemCount
        self.lines = lines
        self.input = input
        self.selection = selection
        self.processingCount = processingCount
        self.isOffline = isOffline
        self.revising = revising
    }
}

/// 휴지통 한 줄(api `TrashItem`). daysLeft는 `30일 남음`(ARC-008 규칙 10).
public struct TrashEntry: Equatable, Sendable, Codable {
    public let item: ItemSummary
    public let trashedAt: String
    public let daysLeft: Int

    public init(item: ItemSummary, trashedAt: String, daysLeft: Int) {
        self.item = item
        self.trashedAt = trashedAt
        self.daysLeft = daysLeft
    }
}

/// 시점(F22). label은 친 낱말 그대로(`지난달`), from·to는 한국 시간 경계의 RFC 3339(반열린 구간).
public struct Period: Equatable, Sendable, Codable {
    public let label: String
    public let from: String
    public let to: String

    public init(label: String, from: String, to: String) {
        self.label = label
        self.from = from
        self.to = to
    }
}

/// `고치기 <번호>` 편집 중인 자료(화면 W24).
public struct Revising: Equatable, Sendable, Codable {
    public let number: Int
    public let title: String
    public let summary: String

    public init(number: Int, title: String, summary: String) {
        self.number = number
        self.title = title
        self.summary = summary
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
    /// `넘기기 <묶음>`이면 그 이름(계약 2). 아니면 nil.
    public let bundle: String?
    /// 묶음에서 휴지통·영구 삭제로 빠진 수 `! 빠진 자료 N건 (삭제됨)`.
    public let removedCount: Int
    /// 줄바꿈을 포함한 글자 수.
    public let charCount: Int
    public let missingSummaryCount: Int
    /// 클립보드에 넣은 글 전체. `펼치기`로 보인다.
    public let text: String

    public init(
        items: [ItemRef],
        bundle: String? = nil,
        removedCount: Int = 0,
        charCount: Int,
        missingSummaryCount: Int,
        text: String
    ) {
        self.items = items
        self.bundle = bundle
        self.removedCount = removedCount
        self.charCount = charCount
        self.missingSummaryCount = missingSummaryCount
        self.text = text
    }
}

/// 저장에 실패한 뒤 사용자가 다시 넣는 길(ARC-005 규칙 2, #57 사용자 결정 2026-11-27).
public enum SaveRecovery: Equatable, Sendable {
    /// 넣으려던 줄을 입력줄에 되돌렸다. `  입력은 남겨 둠`
    case inputKept
    /// 그새 친 새 글이 있어 입력줄을 덮지 않았다. 다음 줄 `→ 다시: <명령>`
    case retry(String)
    /// 끌어다 놓은 파일. 원본은 사용자의 기기에 그대로 있다. ` (<파일 이름>)`
    case file(name: String)
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
public enum TerminalViewAction: Equatable, Sendable {
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
    /// 0건 첫 화면의 `→ 샘플 8건으로 해 보기`. 누르면 바로 저장한다(ARC-010 규칙 2).
    case samplesRequested
    /// `고치기` 편집 칸에서 Enter로 저장했다.
    case reviseSubmitted(number: Int, title: String, summary: String)
    /// `고치기` 편집 칸에서 Esc로 취소했다.
    case reviseCancelled
}

@MainActor
public protocol TerminalPresentableListener: AnyObject {
    func handle(_ action: TerminalViewAction)
}

@MainActor
public protocol TerminalPresentable: Presentable {
    var listener: (any TerminalPresentableListener)? { get set }
    func render(_ state: TerminalViewState)
}

@MainActor
public protocol TerminalViewControllable: ViewControllable {}

@MainActor
public protocol TerminalViewContract: TerminalPresentable, TerminalViewControllable {}

@MainActor
public protocol TerminalViewFactory: AnyObject {
    func makeTerminalView() -> any TerminalViewContract
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
    /// `고치기`(revise)
    case revise
    /// `버리기`(drop)
    case drop
    /// `되살리기`(revive)
    case revive
    /// `휴지통`(bin)
    case bin
    /// `묶음`(pack)
    case pack
    /// `열기`(peek)
    case peek
    /// `찾아두기`(gather)
    case gather
    /// `가져오기`(bring)
    case bring
    /// `연결`(plug)
    case plug
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
