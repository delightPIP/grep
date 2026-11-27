#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FeatureLoggedInInterface
import FeatureLoggedInTesting
import GrepCore
import GrepCoreTesting
import RIBs
import Testing

@testable import FeatureLoggedIn

@MainActor
private final class Dependency: LoggedInDependency {
    let authService: any AuthService
    let httpTransport: any HTTPTransport
    let clipboard: any ClipboardPort = FakeClipboard()
    let files: any FilePort
    let historyStore: any HistoryStore = FakeHistoryStore()
    let sleeper: any Sleeper = FakeSleeper()
    init(authService: any AuthService, httpTransport: any HTTPTransport, files: any FilePort) {
        self.authService = authService
        self.httpTransport = httpTransport
        self.files = files
    }
}

/// LoggedIn 피처 단독 테스트(ACC-001 규칙 6·7, COM-009 규칙 2). 부모와 다른 피처 없이 돈다.
@MainActor
final class LoggedInTests {
    private static let meJSON = #"{"userId":"6f1c0a52-0000-4000-8000-000000000001","authProvider":"google","itemCount":34}"#

    private static let tokenA = fakeAccessToken(subject: "user-a")
    private let auth = FakeAuthService(token: LoggedInTests.tokenA)
    private let transport = FakeHTTPTransport()
    private let files = FakeFilePort()
    private let views = FakeLoggedInViewFactory()
    private let listener = FakeLoggedInListener()
    private let parent = TestParentRouter()
    private var router: (any ViewableRouting)?

    isolated deinit {
        if let router { parent.detach(router) }
    }

    private var view: FakeLoggedInView { views.views.last! }

    private func attach(pendingInput: PendingInput? = nil) async {
        let dependency = Dependency(authService: auth, httpTransport: transport, files: files)
        let builder = LoggedInBuilder(dependency: dependency, viewFactory: views)
        let router = builder.build(listener: listener, pendingInput: pendingInput)
        parent.attach(router)
        self.router = router
        await runCurrent()
    }

    /// `/me` 응답까지 받은 터미널 화면.
    private func attachLoaded() async {
        await attach()
        transport.respond(json: Self.meJSON)
        await runCurrent()
    }

    private func send(_ action: LoggedInViewAction) async {
        view.listener?.handle(action)
        await runCurrent()
    }

    // MARK: 화면 진입과 /me

    @Test func 되살릴줄없이만들었을때_화면에붙으면_빈터미널을그리고토큰을붙여me를요청하는지() async {
        // given
        let expectedRequest = HTTPRequest(method: .get, path: "/me", headers: ["Authorization": "Bearer \(Self.tokenA)"])

        // when
        await attach()

        // then
        #expect(view.states == [LoggedInViewState()])
        #expect(transport.requests == [expectedRequest])
    }

    @Test func 같은계정의되살릴줄과함께만들었을때_화면에붙으면_입력줄에그줄을그리는지() async {
        // given
        let restored = PendingInput(text: "찾기 결제", subject: "user-a")

        // when
        await attach(pendingInput: restored)

        // then
        #expect(view.state == LoggedInViewState(input: "찾기 결제"))
    }

    @Test func 다른계정의되살릴줄과함께만들었을때_화면에붙으면_입력줄을비워두는지() async {
        // given
        let restored = PendingInput(text: "찾기 결제", subject: "user-b")

        // when
        await attach(pendingInput: restored)

        // then
        #expect(view.state == LoggedInViewState())
    }

    @Test func me를기다릴때_서버가자료수를주면_상태줄에그수를그리는지() async {
        // given
        await attach()

        // when
        transport.respond(json: Self.meJSON)
        await runCurrent()

        // then
        #expect(view.state == LoggedInViewState(itemCount: 34))
        #expect(listener.expiredInputs.isEmpty)
    }

    @Test func 접근토큰을받지못할때_화면에붙으면_요청없이만료를알리는지() async {
        // given
        auth.token = nil

        // when
        let restored = PendingInput(text: "찾기 결제", subject: "user-a")
        await attach(pendingInput: restored)

        // then
        #expect(transport.requests.isEmpty)
        #expect(listener.expiredPending == [restored])
    }

    @Test func 입력줄에글을치던중일때_서버가세션만료로답하면_치던줄과함께만료를알리는지() async {
        // given
        await attach()
        await send(.inputChanged("찾기 온보"))

        // when
        transport.respond(status: 401, json: #"{"code":"session_expired"}"#)
        await runCurrent()

        // then
        #expect(listener.expiredPending == [PendingInput(text: "찾기 온보", subject: "user-a")])
    }

    @Test func me를기다릴때_서버가세션만료가아닌401로답하면_만료로보지않는지() async {
        // given
        await attach()

        // when
        transport.respond(status: 401, json: #"{"code":"unauthorized"}"#)
        await runCurrent()

        // then
        #expect(listener.expiredInputs.isEmpty)
        #expect(view.state?.itemCount == nil)
    }

    @Test(arguments: [HTTPTransportError.unreachable, .timedOut])
    func me를기다릴때_응답을받지못하면_자료수없이두고네트워크오류일때만연결끊김을두는지(error: HTTPTransportError) async {
        // given: 네트워크 오류일 때만 상태줄에 `연결 끊김`을 둔다(COM-010 규칙 3)
        let expected = error == .unreachable
            ? [LoggedInViewState(), LoggedInViewState(isOffline: true)]
            : [LoggedInViewState()]
        await attach()

        // when
        transport.respond(.failure(error))
        await runCurrent()

        // then
        #expect(view.states == expected)
        #expect(listener.expiredInputs.isEmpty)
    }

    @Test func me를기다릴때_본문이계약과다르면_자료수없이터미널을그대로두는지() async {
        // given
        await attach()

        // when
        transport.respond(json: #"{"itemCount":"many"}"#)
        await runCurrent()

        // then
        #expect(view.states == [LoggedInViewState()])
    }

    // MARK: 입력

    @Test func 터미널이떠있을때_입력줄이바뀌면_바뀐줄을그리는지() async {
        // given
        await attachLoaded()

        // when
        await send(.inputChanged("찾"))

        // then
        #expect(view.state == LoggedInViewState(itemCount: 34, input: "찾"))
    }

    @Test(arguments: ["로그아웃", "signout", "  로그아웃 "])
    func 터미널이떠있을때_로그아웃명령을치면_세션을끝내고부모에게알리는지(command: String) async {
        // given
        await attachLoaded()

        // when
        await send(.submitted(command))

        // then
        #expect(auth.signOutCount == 1)
        #expect(listener.signOutCount == 1)
    }

    @Test func 터미널이떠있을때_logout을치면_로그아웃하지않고없는명령으로그리는지() async {
        // given
        await attachLoaded()
        await send(.inputChanged("logout"))

        // when
        await send(.submitted("logout"))

        // then
        #expect(auth.signOutCount == 0)
        #expect(listener.signOutCount == 0)
        #expect(view.state == LoggedInViewState(itemCount: 34, lines: [.prompt("logout"), .unknownCommand("logout")], input: ""))
    }

    @Test func 터미널이떠있을때_인자가붙은없는명령을치면_첫낱말을명령이름으로그리는지() async {
        // given
        await attachLoaded()

        // when
        await send(.submitted("찻기 결제"))

        // then
        #expect(view.state?.lines == [.prompt("찻기 결제"), .unknownCommand("찻기")])
    }

    @Test func 없는명령을한번쳤을때_다시없는명령을치면_앞출력뒤에이어서그리는지() async {
        // given
        await attachLoaded()
        await send(.submitted("찻기"))

        // when
        await send(.submitted("최긴"))

        // then
        #expect(view.state?.lines == [.prompt("찻기"), .unknownCommand("찻기"), .prompt("최긴"), .unknownCommand("최긴")])
    }

    @Test func 터미널이떠있을때_빈줄에서엔터를치면_아무것도그리지않는지() async {
        // given
        await attachLoaded()
        let rendersBefore = view.states.count

        // when
        await send(.submitted("   "))

        // then
        #expect(view.states.count == rendersBefore)
    }

    @Test func me를기다리는중에로그아웃을쳤을때_서버가세션만료로답하면_만료가아니라로그아웃으로알리는지() async {
        // given
        await attach()
        await send(.submitted("로그아웃"))

        // when
        transport.respond(status: 401, json: #"{"code":"session_expired"}"#)
        await runCurrent()

        // then
        #expect(listener.signOutCount == 1)
        #expect(listener.expiredInputs.isEmpty)
    }

    // MARK: 담기(#56 계약, ARC-001·ARC-005·COM-001)

    private static let linkItemJSON = #"""
    {"number":30,"kind":"link","title":"카페 텀블러 할인, 올겨울 캠페인 늘었다","source":"carti1108.github.io","status":"received","blockedReason":null,"listSummary":null,"summarySource":null,"partialNote":null,"tags":[],"matchedIn":null,"savedAt":"2026-11-27T11:00:00+09:00"}
    """#

    private static let linkItem = ItemSummary(
        number: 30,
        kind: .link,
        title: "카페 텀블러 할인, 올겨울 캠페인 늘었다",
        source: "carti1108.github.io",
        status: .received,
        tags: [],
        savedAt: "2026-11-27T11:00:00+09:00"
    )

    private struct SaveBody: Decodable, Equatable {
        let kind: String
        let url: String?
        let text: String?
    }

    private func saveBody(of request: HTTPRequest) throws -> SaveBody {
        try JSONDecoder().decode(SaveBody.self, from: Data((request.body ?? "").utf8))
    }

    @Test func 터미널이떠있을때_담기와링크를치면_토큰과멱등성키를붙여링크저장을요청하는지() async throws {
        // given
        await attachLoaded()

        // when
        await send(.submitted("담기 https://carti1108.github.io/grep-seed-demo/l1.html"))

        // then
        let request = try #require(transport.requests.last)
        #expect(request.method == .post)
        #expect(request.path == "/items")
        #expect(request.headers["Authorization"] == "Bearer \(Self.tokenA)")
        #expect(UUID(uuidString: request.headers["Idempotency-Key"] ?? "") != nil)
        #expect(try saveBody(of: request) == SaveBody(kind: "link", url: "https://carti1108.github.io/grep-seed-demo/l1.html", text: nil))
    }

    @Test(arguments: ["담기 오늘 회의 메모: 텀블러 캠페인", "keep ftp://example.com/a"])
    func 터미널이떠있을때_담기뒤에링크가아닌글을치면_글저장을요청하는지(line: String) async throws {
        // given
        await attachLoaded()
        let text = String(line.drop(while: { !$0.isWhitespace }).dropFirst())

        // when
        await send(.submitted(line))

        // then
        let request = try #require(transport.requests.last)
        #expect(try saveBody(of: request) == SaveBody(kind: "text", url: nil, text: text))
    }

    @Test func 링크저장을기다릴때_서버가저장됨으로답하면_저장됨줄을그리고자료수를하나늘리는지() async {
        // given
        await attachLoaded()
        let line = "담기 https://carti1108.github.io/grep-seed-demo/l1.html"
        await send(.submitted(line))

        // when
        transport.respond(status: 201, json: #"{"result":"saved","item":\#(Self.linkItemJSON)}"#)
        await runCurrent()

        // then
        #expect(view.state == LoggedInViewState(itemCount: 35, lines: [.prompt(line), .saved(Self.linkItem)], processingCount: 1))
    }

    @Test func 링크저장을기다릴때_서버가이미있음으로답하면_기존자료를보이고자료수를그대로두는지() async {
        // given
        await attachLoaded()
        let line = "담기 https://carti1108.github.io/grep-seed-demo/l1.html"
        await send(.submitted(line))

        // when
        transport.respond(json: #"{"result":"duplicate","item":\#(Self.linkItemJSON)}"#)
        await runCurrent()

        // then
        #expect(view.state == LoggedInViewState(itemCount: 34, lines: [.prompt(line), .alreadySaved(Self.linkItem)], processingCount: 1))
    }

    @Test func 링크저장을기다릴때_서버가휴지통에있음으로답하면_휴지통줄을그리는지() async {
        // given
        await attachLoaded()
        let line = "담기 https://carti1108.github.io/grep-seed-demo/l1.html"
        await send(.submitted(line))

        // when
        transport.respond(json: #"{"result":"inTrash","item":\#(Self.linkItemJSON)}"#)
        await runCurrent()

        // then
        #expect(view.state == LoggedInViewState(itemCount: 34, lines: [.prompt(line), .inTrash(number: 30)]))
    }

    @Test(arguments: [
        (Result<HTTPResponse, HTTPTransportError>.failure(.unreachable), SaveFailure.disconnected),
        (.failure(.timedOut), .timedOut),
        (.success(HTTPResponse(status: 500, body: [])), .serverError),
    ])
    func 링크저장을기다릴때_저장에실패하면_실패줄을그리고친줄을입력줄에남기는지(
        response: Result<HTTPResponse, HTTPTransportError>, reason: SaveFailure
    ) async {
        // given
        await attachLoaded()
        let line = "담기 https://carti1108.github.io/grep-seed-demo/l1.html"
        await send(.submitted(line))

        // when
        transport.respond(response)
        await runCurrent()

        // then
        #expect(view.state == LoggedInViewState(
            itemCount: 34, lines: [.prompt(line), .saveFailed(reason, .inputKept)], input: line,
            isOffline: reason == .disconnected
        ))
    }

    @Test func 링크저장을기다릴때_서버가세션만료로답하면_친줄과함께만료를알리는지() async {
        // given
        await attachLoaded()
        let line = "담기 https://carti1108.github.io/grep-seed-demo/l1.html"
        await send(.submitted(line))

        // when
        transport.respond(status: 401, json: #"{"code":"session_expired"}"#)
        await runCurrent()

        // then
        #expect(listener.expiredInputs == [line])
    }

    @Test func 저장이응답없음으로실패했을때_되살린줄을그대로다시치면_같은멱등성키로요청하는지() async throws {
        // given
        await attachLoaded()
        let line = "담기 오늘 회의 메모"
        await send(.submitted(line))
        transport.respond(.failure(.timedOut))
        await runCurrent()
        let firstKey = try #require(transport.requests.last?.headers["Idempotency-Key"])

        // when
        await send(.submitted(line))

        // then
        #expect(transport.requests.last?.headers["Idempotency-Key"] == firstKey)
    }

    @Test func 저장이끝났을때_같은줄을다시치면_새멱등성키로요청하는지() async throws {
        // given
        await attachLoaded()
        let line = "담기 오늘 회의 메모"
        await send(.submitted(line))
        transport.respond(status: 201, json: #"{"result":"saved","item":\#(Self.linkItemJSON)}"#)
        await runCurrent()
        let firstKey = try #require(transport.requests.last?.headers["Idempotency-Key"])

        // when
        await send(.submitted(line))

        // then
        #expect(transport.requests.last?.headers["Idempotency-Key"] != firstKey)
    }

    @Test func 저장을기다리는중에새글을쳤을때_저장이실패하면_친새글을덮어쓰지않는지() async {
        // given
        await attachLoaded()
        await send(.submitted("담기 https://example.com/a"))
        await send(.inputChanged("찾기 텀블러"))

        // when
        transport.respond(.failure(.unreachable))
        await runCurrent()

        // then
        #expect(view.state?.input == "찾기 텀블러")
        #expect(view.state?.lines.last == .saveFailed(.disconnected, .retry("담기 https://example.com/a")))
    }

    @Test func 터미널이떠있을때_담기만치면_요청없이빠진인자줄을그리는지() async {
        // given
        await attachLoaded()
        let requestsBefore = transport.requests.count

        // when
        await send(.submitted("담기"))

        // then
        #expect(transport.requests.count == requestsBefore)
        #expect(view.state?.lines == [.prompt("담기"), .missingArgument(.keep)])
    }

    // MARK: 붙여 넣기(#57, user-flow 3절 1단계)

    @Test func 터미널이떠있을때_링크를붙여넣으면_명령없이링크저장을요청하고담기줄로찍는지() async throws {
        // given
        await attachLoaded()
        let link = "https://carti1108.github.io/grep-seed-demo/l1.html"

        // when
        await send(.pasted(link))

        // then
        let request = try #require(transport.requests.last)
        #expect(request.path == "/items")
        #expect(try saveBody(of: request) == SaveBody(kind: "link", url: link, text: nil))
        #expect(view.state?.lines == [.prompt("담기 \(link)")])
    }

    @Test func 터미널이떠있을때_여러줄글을붙여넣으면_줄바꿈을살려글저장을요청하는지() async throws {
        // given
        await attachLoaded()
        let memo = "텀블러 세척 메모\n베이킹소다 한 숟갈"

        // when
        await send(.pasted("  \(memo)\n"))

        // then
        #expect(try saveBody(of: try #require(transport.requests.last)) == SaveBody(kind: "text", url: nil, text: memo))
    }

    @Test func 붙여넣은링크저장이실패했을때_입력줄을보면_담기와그링크가남아있는지() async {
        // given
        await attachLoaded()
        let link = "https://example.com/a"
        await send(.pasted(link))

        // when
        transport.respond(.failure(.timedOut))
        await runCurrent()

        // then
        #expect(view.state?.input == "담기 \(link)")
        #expect(view.state?.lines.last == .saveFailed(.timedOut, .inputKept))
    }

    @Test func 터미널이떠있을때_빈글을붙여넣으면_요청하지않는지() async {
        // given
        await attachLoaded()
        let requestsBefore = transport.requests.count

        // when
        await send(.pasted(" \n "))

        // then
        #expect(transport.requests.count == requestsBefore)
    }

    // MARK: 끌어다 놓기(#57, COM-004 규칙 3·8)

    private static let pdf = DroppedFile(id: "f1", name: "겨울 굿즈 예산안.pdf", size: 120_000)
    private static let uploadJSON = #"{"uploadId":"7c0b6a52-0000-4000-8000-000000000001","uploadUrl":"https://storage.test/put/1","expiresAt":"2026-11-27T12:00:00+09:00"}"#
    private static let fileItem = ItemSummary(
        number: 35, kind: .file, title: "겨울 굿즈 예산안.pdf", source: "pdf", status: .received, tags: [],
        savedAt: "2026-11-27T11:00:00+09:00"
    )
    private static let fileItemJSON = #"{"number":35,"kind":"file","title":"겨울 굿즈 예산안.pdf","source":"pdf","status":"received","blockedReason":null,"listSummary":null,"summarySource":null,"partialNote":null,"tags":[],"matchedIn":null,"savedAt":"2026-11-27T11:00:00+09:00"}"#

    private struct UploadBody: Decodable, Equatable {
        let fileName: String
        let size: Int
    }

    private struct FileSaveBody: Decodable, Equatable {
        let kind: String
        let uploadId: String
    }

    @Test func 파일하나를놓았을때_서버가모두받으면_자리를받아올리고저장해저장됨줄을그리는지() async throws {
        // given
        await attachLoaded()

        // when
        await send(.filesDropped([Self.pdf]))
        transport.respond(status: 201, json: Self.uploadJSON)
        await runCurrent()
        transport.respond(status: 201, json: #"{"result":"saved","item":\#(Self.fileItemJSON)}"#)
        await runCurrent()

        // then
        let uploadRequest = try #require(transport.requests.dropFirst().first)
        #expect(uploadRequest.path == "/uploads")
        #expect(try JSONDecoder().decode(UploadBody.self, from: Data((uploadRequest.body ?? "").utf8))
            == UploadBody(fileName: "겨울 굿즈 예산안.pdf", size: 120_000))
        #expect(files.uploads.map(\.uploadURL) == ["https://storage.test/put/1"])
        let saveRequest = try #require(transport.requests.last)
        #expect(saveRequest.path == "/items")
        #expect(saveRequest.headers["Idempotency-Key"] != nil)
        #expect(try JSONDecoder().decode(FileSaveBody.self, from: Data((saveRequest.body ?? "").utf8))
            == FileSaveBody(kind: "file", uploadId: "7c0b6a52-0000-4000-8000-000000000001"))
        #expect(view.state?.lines == [.prompt("담기 겨울 굿즈 예산안.pdf"), .saved(Self.fileItem)])
        #expect(view.state?.itemCount == 35)
        #expect(files.released == ["f1"])
    }

    @Test func 두파일을놓았을때_첫파일이20MB를넘으면_그파일만실패로알리고둘째는저장하는지() async {
        // given
        await attachLoaded()
        let big = DroppedFile(id: "f0", name: "영상.mov", size: 30_000_000)

        // when
        await send(.filesDropped([big, Self.pdf]))
        transport.respond(status: 413, json: #"{"code":"file_too_large","fileName":"영상.mov","bytes":30000000}"#)
        await runCurrent()
        transport.respond(status: 201, json: Self.uploadJSON)
        await runCurrent()
        transport.respond(status: 201, json: #"{"result":"saved","item":\#(Self.fileItemJSON)}"#)
        await runCurrent()

        // then
        #expect(view.state?.lines == [
            .prompt("담기 영상.mov 겨울 굿즈 예산안.pdf"),
            .saveFailed(.tooLarge(fileName: "영상.mov", bytes: 30_000_000), .file(name: "영상.mov")),
            .saved(Self.fileItem),
        ])
        #expect(files.released == ["f0", "f1"])
    }

    @Test func 파일을올린뒤_서버가받지않는형식이라하면_확장자를넣어실패로알리는지() async {
        // given
        await attachLoaded()
        let zip = DroppedFile(id: "z", name: "자료.pdf", size: 10)
        await send(.filesDropped([zip]))
        transport.respond(status: 201, json: Self.uploadJSON)
        await runCurrent()

        // when
        transport.respond(status: 415, json: #"{"code":"unsupported_format","fileExtension":"zip"}"#)
        await runCurrent()

        // then
        #expect(view.state?.lines.last == .saveFailed(.unsupportedFormat(fileExtension: "zip"), .file(name: "자료.pdf")))
    }

    @Test func 파일을놓았을때_올리기가연결끊김이면_서버저장을부르지않고실패로알리는지() async {
        // given
        await attachLoaded()
        files.failure = .unreachable
        await send(.filesDropped([Self.pdf]))

        // when
        transport.respond(status: 201, json: Self.uploadJSON)
        await runCurrent()

        // then
        #expect(transport.requests.last?.path == "/uploads")
        #expect(view.state?.lines.last == .saveFailed(.disconnected, .file(name: "겨울 굿즈 예산안.pdf")))
        #expect(files.released == ["f1"])
    }

    // MARK: 생명주기

    @Test func me를기다릴때_화면이떼어지면_입력을끊고늦은응답을그리지않는지() async {
        // given
        await attach()
        let rendersBefore = view.states.count

        // when
        parent.detach(router!)
        router = nil
        transport.respond(json: Self.meJSON)
        await runCurrent()

        // then
        #expect(view.listener == nil)
        #expect(view.states.count == rendersBefore)
        #expect(listener.expiredInputs.isEmpty)
    }
}
