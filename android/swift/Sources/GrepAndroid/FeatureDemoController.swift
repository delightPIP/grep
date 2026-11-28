import FeatureLoggedOut
import FeatureLoggedOutAndroid
import FeatureLoggedOutInterface
import FeatureTerminalAndroid
import FeatureTerminalInterface
import GrepAndroidSupport
import GrepCore
import GrepCoreTesting
import RIBs
import RIBsAndroid

/// 피처 하나만 띄운다. 부모는 `TestParentRouter`가 맡고,
/// 부모에게 갈 이벤트는 루트 화면의 `event`로 보여 준다.
@MainActor
public final class FeatureDemoController: RibController {
    private let feature: DemoFeature
    private let scenarioName: String
    public let authService: any AuthService
    private let stack: RenderStack
    private let root: HostRootScreen
    private let parent = TestParentRouter()
    private var router: (any ViewableRouting)?

    public init(
        feature: DemoFeature,
        scenarioName: String = "initial",
        authService: (any AuthService)? = nil,
        sink: @escaping (String) -> Void
    ) {
        self.feature = feature
        self.scenarioName = scenarioName
        let loggedOutScenario = DemoLoggedOutScenario(rawValue: scenarioName) ?? .initial
        self.authService = authService ?? Self.makeAuthService(for: loggedOutScenario)
        stack = RenderStack(sink: sink)
        root = HostRootScreen(context: stack.context)
    }

    public convenience init(
        feature: DemoFeature,
        scenario: DemoLoggedOutScenario,
        authService: (any AuthService)? = nil,
        sink: @escaping (String) -> Void
    ) {
        self.init(feature: feature, scenarioName: scenario.rawValue, authService: authService, sink: sink)
    }

    public convenience init(
        feature: DemoFeature,
        terminalScenario: DemoTerminalScenario,
        sink: @escaping (String) -> Void
    ) {
        self.init(feature: feature, scenarioName: terminalScenario.rawValue, authService: nil, sink: sink)
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
            let scenario = DemoLoggedOutScenario(rawValue: scenarioName) ?? .initial
            let notice: LoggedOutViewState.Notice? = switch scenario {
            case .expired: .expired
            case .signedOut: .signedOut
            default: nil
            }
            return LoggedOutBuilder(dependency: self, viewFactory: LoggedOutAndroidViewFactory(context: context))
                .build(listener: self, notice: notice)
        case .terminal:
            let scenario = DemoTerminalScenario(rawValue: scenarioName) ?? .welcome
            let screen = TerminalAndroidViewFactory(context: context).makeTerminalView()
            let interactor = DemoTerminalInteractor(
                presenter: screen,
                scenario: scenario,
                onEvent: { [weak self] event in self?.root.showEvent(event) }
            )
            return DemoTerminalRouter(interactor: interactor, viewController: screen)
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

extension FeatureDemoController: LoggedOutDependency {}

extension FeatureDemoController: LoggedOutListener {
    public func didSignIn() { root.showEvent("didSignIn()") }
}
