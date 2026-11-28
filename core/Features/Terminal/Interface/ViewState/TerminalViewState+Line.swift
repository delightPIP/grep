import GrepCore

extension TerminalViewState {
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
        /// `related`는 뜻이 가까운 자료(#128). 있으면 뷰가 `· 뜻이 가까운 자료 N건 (낱말은 다름)`을 그린다.
        case noResults(query: SearchQuery, recent: [ItemSummary], period: Period? = nil, related: [ItemSummary] = [])
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
        /// #172 받지 않는 형식 줄 다음 `→ 북마크 파일이면: 가져오기`. 끌어다 놓은 `html`·`htm` 파일의 이름.
        case importSuggest(fileName: String)
    }
}
