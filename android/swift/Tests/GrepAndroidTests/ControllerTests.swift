import FeatureLoggedOutAndroid
import FeatureLoggedOutInterface
import FeatureTerminalAndroid
import FeatureTerminalInterface
import GrepAndroid
import GrepAppRoot
import GrepCore
import GrepCoreTesting
import Testing

@MainActor
struct ControllerTests {
    @Test
    func 세션이없을때_앱을시작하면_로그인화면이붙는지() async {
        // given
        let auth = FakeAuthService(token: nil)
        let platform = PlatformServices(
            authService: auth,
            httpTransport: FakeHTTPTransport(),
            clipboard: FakeClipboard(),
            files: FakeFilePort(),
            historyStore: FakeHistoryStore()
        )
        var trees: [String] = []
        let controller = GrepAppController(platform: platform) { trees.append($0) }

        // when
        controller.start()
        await runCurrent()

        // then
        #expect(controller.encodedTree.contains("\"kind\":\"loggedOut\""))
        #expect(!trees.isEmpty)
        controller.stop()
    }

    @Test
    func 세션이남아있을때_앱을시작하면_터미널화면이붙는지() async {
        // given
        let auth = FakeAuthService(token: fakeAccessToken(subject: "user-1"))
        let platform = PlatformServices(
            authService: auth,
            httpTransport: FakeHTTPTransport(),
            clipboard: FakeClipboard(),
            files: FakeFilePort(),
            historyStore: FakeHistoryStore()
        )
        let controller = GrepAppController(platform: platform) { _ in }

        // when
        controller.start()
        await runCurrent()

        // then
        #expect(controller.encodedTree.contains("\"kind\":\"terminal\""))
        controller.stop()
    }

    @Test
    func 로그인만료시나리오일때_데모를시작하면_만료안내가표시되는지() async {
        // given
        let controller = FeatureDemoController(feature: .loggedOut, scenario: .expired) { _ in }

        // when
        controller.start()
        await runCurrent()

        // then
        #expect(controller.encodedTree.contains("\"kind\":\"loggedOut\""))
        controller.stop()
    }

    @Test
    func 터미널데모시나리오일때_시작하면_터미널화면이붙고만료이벤트가전달되는지() async {
        // given
        let controller = FeatureDemoController(feature: .terminal, terminalScenario: .expired) { _ in }

        // when
        controller.start()
        await runCurrent()

        // then
        #expect(controller.encodedTree.contains("\"kind\":\"terminal\""))
        #expect(controller.encodedTree.contains("didExpire"))
        controller.stop()
    }

    @Test
    func 터미널상태에고르기와넘기기확인이있을때_JSON인코딩하면_필드가보존되는지() {
        // given
        let ref = ItemRef(number: 131, title: "웹훅 정책")
        let state = TerminalViewState(
            itemCount: 23,
            lines: [
                .prompt("고르기 131"),
                .picked([ref]),
                .handoffConfirm(total: 23),
                .guide,
            ],
            input: "넘기기",
            selection: [ref],
            processingCount: 2,
            isOffline: true
        )

        // when
        let json = TerminalStateEncoder.encode(state)

        // then
        #expect(json.contains("\"itemCount\":23"))
        #expect(json.contains("\"processingCount\":2"))
        #expect(json.contains("\"isOffline\":true"))
        #expect(json.contains("\"kind\":\"picked\""))
        #expect(json.contains("\"kind\":\"handoffConfirm\""))
        #expect(json.contains("\"total\":23"))
        #expect(json.contains("\"kind\":\"guide\""))
    }
}
