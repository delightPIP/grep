import FeatureLoggedOutAndroid
import FeatureLoggedOutInterface
import FeatureTerminalAndroid
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
}
