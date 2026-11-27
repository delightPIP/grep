import FeatureLoggedOut
import FeatureLoggedOutAndroid
import FeatureLoggedOutInterface
import GrepAndroidSupport
import GrepCore
import GrepCoreTesting
import RIBs
import RIBsAndroid

/// 단독 실행 앱이 띄울 수 있는 피처. Kotlin demo 모듈이 이 문자열로 고른다.
public enum DemoFeature: String, CaseIterable, Sendable {
    case loggedOut
}

/// 단독 실행 앱에서 로그인 화면 시나리오를 고르기 위한 설정.
public enum DemoLoggedOutScenario: String, CaseIterable, Sendable {
    case initial
    case expired
    case signedOut
    case failDisconnected
    case failTimedOut
    case failDenied
    case cancelled
}

/// 피처 하나만 띄운다. 부모는 `TestParentRouter`가 맡고,
/// 부모에게 갈 이벤트는 루트 화면의 `event`로 보여 준다.
@MainActor
public final class FeatureDemoController: RibController {
    private let feature: DemoFeature
    private let scenario: DemoLoggedOutScenario
    public let authService: any AuthService
    private let stack: RenderStack
    private let root: HostRootScreen
    private let parent = TestParentRouter()
    private var router: (any ViewableRouting)?

    public init(
        feature: DemoFeature,
        scenario: DemoLoggedOutScenario = .initial,
        authService: (any AuthService)? = nil,
        sink: @escaping (String) -> Void
    ) {
        self.feature = feature
        self.scenario = scenario
        self.authService = authService ?? Self.makeAuthService(for: scenario)
        stack = RenderStack(sink: sink)
        root = HostRootScreen(context: stack.context)
    }

    public func start() {
        precondition(router == nil, "FeatureDemoController.start called twice without stop")
        stack.host.show(root)
        let child = build()
        parent.attach(child)
        root.showScreen(child.viewControllable)
        router = child
    }

    public func screen<Screen: AndroidScreen>(id: Int64, as type: Screen.Type) -> Screen? {
        stack.registry.screen(id: id, as: type)
    }

    public func stop() {
        guard let child = router else { return }
        parent.detach(child)
        root.hideScreen(child.viewControllable)
        stack.host.hide(root)
        router = nil
    }

    public var encodedTree: String { stack.renderer.encodedTree }

    private func build() -> any ViewableRouting {
        let context = stack.context
        switch feature {
        case .loggedOut:
            let notice: LoggedOutViewState.Notice? = switch scenario {
            case .expired: .expired
            case .signedOut: .signedOut
            default: nil
            }
            return LoggedOutBuilder(dependency: self, viewFactory: LoggedOutAndroidViewFactory(context: context))
                .build(listener: self, notice: notice)
        }
    }

    private static func makeAuthService(for scenario: DemoLoggedOutScenario) -> any AuthService {
        let result: SignInResult = switch scenario {
        case .initial, .expired, .signedOut:
            .success
        case .failDisconnected:
            .failed(.disconnected)
        case .failTimedOut:
            .failed(.timedOut)
        case .failDenied:
            .failed(.denied)
        case .cancelled:
            .cancelled
        }
        return DemoAuthService(result: result)
    }
}

@MainActor
private final class DemoAuthService: AuthService {
    private let result: SignInResult
    private var token: String?

    init(result: SignInResult) {
        self.result = result
    }

    func signIn(_ provider: AuthProvider) async -> SignInResult {
        if result == .success {
            token = fakeAccessToken(subject: "demo-\(provider.rawValue)")
        }
        return result
    }

    func signOut() async {
        token = nil
    }

    func accessToken() async -> String? { token }
}

extension FeatureDemoController: LoggedOutDependency {}

extension FeatureDemoController: LoggedOutListener {
    public func didSignIn() { root.showEvent("didSignIn()") }
}
