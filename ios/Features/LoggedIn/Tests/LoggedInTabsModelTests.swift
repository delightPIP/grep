import FeatureLoggedInAdapter
import FeatureLoggedInUI
import Foundation
import GrepCore
import Testing

@MainActor
struct LoggedInTabsModelTests {
    @Test func 기본초기화일때_시작탭을확인하면_늘터미널탭인지() {
        // given
        let loader = StubArchiveLoader(outcomes: [])

        // when
        let model = LoggedInTabsModel(archiveLoader: loader, onSignOut: {})

        // then
        #expect(model.selectedTab == .terminal)
    }

    @Test func 보관함목록을불러온뒤더보기를누를때_다음쪽을받으면_중복없이이어붙이는지() async {
        // given
        let first = makeItem(number: 3, title: "셋째")
        let second = makeItem(number: 2, title: "둘째")
        let third = makeItem(number: 1, title: "첫째")
        let loader = StubArchiveLoader(outcomes: [
            .page(items: [first, second], nextCursor: "c2"),
            .page(items: [second, third], nextCursor: nil),
        ])
        let model = LoggedInTabsModel(archiveLoader: loader, pageLimit: 2, onSignOut: {})

        // when
        await model.loadArchiveIfNeeded()
        await model.loadMoreArchive()

        // then
        #expect(loader.requestedCursors == [nil, "c2"])
        #expect(model.archivePresentation.items.map(\.number) == [3, 2, 1])
        #expect(!model.archivePresentation.hasMore)
        #expect(model.archivePresentation.statusText == "자료 3")
    }

    @Test func 보관함불러오기가실패했을때_다시시도하면_오류를지우고목록을표시하는지() async {
        // given
        let item = makeItem(number: 10, title: "복구된 자료")
        let loader = StubArchiveLoader(outcomes: [
            .failed(.disconnected),
            .page(items: [item], nextCursor: nil),
        ])
        let model = LoggedInTabsModel(archiveLoader: loader, onSignOut: {})

        // when
        await model.loadArchiveIfNeeded()
        let errorBeforeRetry = model.archivePresentation.errorMessage
        await model.refreshArchive()

        // then
        #expect(errorBeforeRetry == "연결 끊김")
        #expect(model.archivePresentation.errorMessage == nil)
        #expect(model.archivePresentation.items.map(\.number) == [10])
    }

    @Test func 설정에서로그아웃을요청했을때_중복호출하면_콜백을한번만부르는지() {
        // given
        var signOutCount = 0
        let model = LoggedInTabsModel(
            archiveLoader: StubArchiveLoader(outcomes: []),
            onSignOut: { signOutCount += 1 }
        )

        // when
        model.requestSignOut()
        model.requestSignOut()

        // then
        #expect(signOutCount == 1)
        #expect(model.settingsPresentation.isSigningOut)
    }

    @Test func 설정에서모든기기로그아웃을확인했을때_중복호출하면_모든기기콜백만한번부르는지() {
        // given
        var signOutCount = 0
        var everywhereCount = 0
        let model = LoggedInTabsModel(
            archiveLoader: StubArchiveLoader(outcomes: []),
            onSignOut: { signOutCount += 1 },
            onSignOutEverywhere: { everywhereCount += 1 }
        )

        // when
        model.requestSignOutEverywhere()
        model.requestSignOutEverywhere()
        model.requestSignOut()

        // then
        #expect(everywhereCount == 1)
        #expect(signOutCount == 0)
        #expect(model.settingsPresentation.isSigningOut)
        #expect(model.settingsPresentation.canSignOutEverywhere)
    }

    @Test func 모든기기콜백이없을때_설정을그리면_모든기기버튼을막는지() {
        // given
        let model = LoggedInTabsModel(archiveLoader: StubArchiveLoader(outcomes: []), onSignOut: {})

        // when
        let presentation = model.settingsPresentation

        // then
        #expect(!presentation.canSignOutEverywhere)
    }

    @Test func 같은탭을다시눌렀을때_reselect를호출하면_해당탭트리거만증가하는지() {
        // given
        let model = LoggedInTabsModel(archiveLoader: StubArchiveLoader(outcomes: []), onSignOut: {})

        // when
        model.reselect(tab: .terminal)
        model.reselect(tab: .archive)
        model.reselect(tab: .settings)

        // then
        #expect(model.terminalScrollToBottomTrigger == 1)
        #expect(model.archiveScrollToTopTrigger == 1)
        #expect(model.settingsResetToRootTrigger == 1)
    }

    @Test func 보관함에서자료를고른상태일때_isPickingInArchive와해제를확인하면_탭바숨김과해제가동작하는지() async {
        // given
        let item = makeItem(number: 28, title: "파란컵 캡처.png")
        let loader = StubArchiveLoader(outcomes: [.page(items: [item], nextCursor: nil)])
        let model = LoggedInTabsModel(archiveLoader: loader, initialTab: .archive, onSignOut: {})
        await model.loadArchiveIfNeeded()

        // when
        model.updateTerminalContext(itemCount: 1, pickedNumbers: [28])
        let pickingBeforeClear = model.isPickingInArchive
        let summaryBeforeClear = model.archivePresentation.pickedSummary
        model.clearPicked()

        // then
        #expect(pickingBeforeClear)
        #expect(summaryBeforeClear == "28 파란컵 캡처.png")
        #expect(!model.isPickingInArchive)
        #expect(model.archivePresentation.pickedCount == 0)
    }

    @Test func 터미널과이어졌을때_보관함에서해제를누르면_터미널선택비우기만부르는지() {
        // given
        var clearCount = 0
        let model = LoggedInTabsModel(
            archiveLoader: StubArchiveLoader(outcomes: []),
            initialTab: .archive,
            onSignOut: {},
            onClearPicked: { clearCount += 1 }
        )
        model.updateTerminalContext(itemCount: 2, pickedNumbers: [28, 30])

        // when
        model.clearPicked()

        // then
        #expect(clearCount == 1)
        // 표시는 터미널 선택이 실제로 바뀐 뒤(updateTerminalContext) 따라 바뀐다.
        #expect(model.archivePresentation.pickedCount == 2)
    }

    @Test func 이미고른자료를보관함에서다시누르면_빼기를부르고고르기는부르지않는지() {
        // given
        var picked: [Int] = []
        var unpicked: [Int] = []
        let model = LoggedInTabsModel(
            archiveLoader: StubArchiveLoader(outcomes: []),
            initialTab: .archive,
            onSignOut: {},
            onPickItem: { picked.append($0) },
            onUnpickItem: { unpicked.append($0) }
        )
        model.updateTerminalContext(itemCount: 2, pickedNumbers: [28])

        // when
        model.togglePick(number: 28)
        model.togglePick(number: 30)

        // then
        #expect(unpicked == [28])
        #expect(picked == [30])
    }

    @Test func 빼기콜백이없을때_고른자료를다시누르면_고르기콜백으로넘기는지() {
        // given
        var picked: [Int] = []
        let model = LoggedInTabsModel(
            archiveLoader: StubArchiveLoader(outcomes: []),
            onSignOut: {},
            onPickItem: { picked.append($0) }
        )
        model.updateTerminalContext(itemCount: 1, pickedNumbers: [28])

        // when
        model.togglePick(number: 28)

        // then
        #expect(picked == [28])
    }

    @Test func HTTPArchiveItemLoader가401세션만료를받았을때_loadPage를부르면_sessionExpired를돌려주는지() async {
        // given
        let auth = StubAuthService(token: "valid-token")
        let transport = StubHTTPTransport(
            result: .success(HTTPResponse(status: 401, body: Array(#"{"code":"session_expired"}"#.utf8)))
        )
        let loader = HTTPArchiveItemLoader(authService: auth, httpTransport: transport)

        // when
        let outcome = await loader.loadPage(limit: 20, cursor: "next+1")

        // then
        #expect(outcome == .sessionExpired)
        #expect(transport.lastRequest?.path == "/items?limit=20&cursor=next%2B1")
        #expect(transport.lastRequest?.headers["Authorization"] == "Bearer valid-token")
    }

    @Test func HTTPArchiveItemLoader가연결불가오류를받았을때_loadPage를부르면_disconnected를돌려주는지() async {
        // given
        let auth = StubAuthService(token: "valid-token")
        let transport = StubHTTPTransport(result: .failure(.unreachable))
        let loader = HTTPArchiveItemLoader(authService: auth, httpTransport: transport)

        // when
        let outcome = await loader.loadPage(limit: 20, cursor: nil)

        // then
        #expect(outcome == .failed(.disconnected))
    }

    private func makeItem(number: Int, title: String) -> ItemSummary {
        ItemSummary(
            number: number,
            kind: .link,
            title: title,
            source: "example.com",
            status: .ready,
            listSummary: "요약",
            tags: ["태그"],
            savedAt: "2026-11-26T05:03:00Z"
        )
    }
}

@MainActor
private final class StubArchiveLoader: ArchiveItemLoader {
    private var outcomes: [ArchivePageOutcome]
    private(set) var requestedCursors: [String?] = []

    init(outcomes: [ArchivePageOutcome]) {
        self.outcomes = outcomes
    }

    func loadPage(limit: Int, cursor: String?) async -> ArchivePageOutcome {
        requestedCursors.append(cursor)
        guard !outcomes.isEmpty else { return .page(items: [], nextCursor: nil) }
        return outcomes.removeFirst()
    }
}

@MainActor
private final class StubAuthService: AuthService {
    private let token: String?

    init(token: String?) {
        self.token = token
    }

    func signIn(_ provider: AuthProvider) async -> SignInResult { .success }
    func signOut() async {}
    func accessToken() async -> String? { token }
}

@MainActor
private final class StubHTTPTransport: HTTPTransport {
    private let result: Result<HTTPResponse, HTTPTransportError>
    private(set) var lastRequest: HTTPRequest?

    init(result: Result<HTTPResponse, HTTPTransportError>) {
        self.result = result
    }

    func send(_ request: HTTPRequest) async throws(HTTPTransportError) -> HTTPResponse {
        lastRequest = request
        return try result.get()
    }
}
