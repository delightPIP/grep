import FeatureLoggedOut
import FeatureLoggedOutAdapter
import FeatureLoggedOutInterface
import GrepCore
import GrepCoreTesting
import Observation
import RIBs
import RIBsSwiftUI
import SwiftUI

enum LoggedOutDemoScenario: String, CaseIterable, Identifiable {
    case initialSuccess = "첫 화면 (로그인 성공)"
    case expired = "로그인 만료 알림"
    case signedOut = "로그아웃 완료 알림"
    case cancelled = "로그인 취소 응답"
    case disconnected = "로그인 실패: 연결 끊김"
    case timedOut = "로그인 실패: 응답 없음"
    case denied = "로그인 실패: 권한 거부"

    var id: String { rawValue }
}

/// 로그인 피처 단독 Example 앱. 시나리오 목록에서 항목을 고르면 전체 화면으로 피처를 띄운다.
@main
struct LoggedOutExampleApp: App {
    @State private var harness = LoggedOutExampleHarness()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                List {
                    Section("시나리오") {
                        ForEach(LoggedOutDemoScenario.allCases) { scenario in
                            Button(scenario.rawValue) {
                                harness.launch(scenario)
                            }
                        }
                    }
                    Section("마지막 부모 이벤트") {
                        Text(harness.lastEvent)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("exampleEvent")
                    }
                }
                .navigationTitle("LoggedOut Scenarios")
            }
            .fullScreenCover(item: $harness.activeScenario, onDismiss: { harness.stop() }) { _ in
                ZStack(alignment: .topTrailing) {
                    RIBSlotView(slot: harness.slot)
                    Button("닫기") {
                        harness.activeScenario = nil
                    }
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 54)
                    .padding(.trailing, 12)
                    .accessibilityIdentifier("closeScenarioButton")
                }
            }
        }
    }
}

@MainActor @Observable
final class LoggedOutExampleHarness: LoggedOutListener, LoggedOutDependency {
    let slot = RIBScreenSlot()
    var activeScenario: LoggedOutDemoScenario?
    private(set) var lastEvent = "부모 이벤트 없음"

    @ObservationIgnored private let exampleAuth = ExampleAuthService()
    var authService: any AuthService { exampleAuth }
    @ObservationIgnored private let parent = TestParentRouter()
    @ObservationIgnored private var currentRouter: (any ViewableRouting)?

    func launch(_ scenario: LoggedOutDemoScenario) {
        stop()
        let notice: LoggedOutViewState.Notice?
        let nextResult: SignInResult
        switch scenario {
        case .initialSuccess:
            notice = nil; nextResult = .success
        case .expired:
            notice = .expired; nextResult = .success
        case .signedOut:
            notice = .signedOut; nextResult = .success
        case .cancelled:
            notice = nil; nextResult = .cancelled
        case .disconnected:
            notice = nil; nextResult = .failed(.disconnected)
        case .timedOut:
            notice = nil; nextResult = .failed(.timedOut)
        case .denied:
            notice = nil; nextResult = .failed(.denied)
        }

        exampleAuth.nextResult = nextResult
        let router = LoggedOutBuilder(dependency: self, viewFactory: LoggedOutScreenFactory())
            .build(listener: self, notice: notice)
        parent.attach(router)
        slot.show(router.viewControllable)
        currentRouter = router
        activeScenario = scenario
    }

    func stop() {
        if let existing = currentRouter {
            parent.detach(existing)
            slot.hide(existing.viewControllable)
            currentRouter = nil
        }
    }

    func didSignIn() {
        lastEvent = "didSignIn() 수신"
        activeScenario = nil
    }
}

@MainActor
private final class ExampleAuthService: AuthService {
    var nextResult: SignInResult = .success
    private var token: String?

    func signIn(_ provider: AuthProvider) async -> SignInResult {
        try? await Task.sleep(for: .milliseconds(400))
        if nextResult == .success {
            token = fakeAccessToken(subject: "example-\(provider.rawValue)")
        }
        return nextResult
    }

    func signOut() async {
        token = nil
    }

    func accessToken() async -> String? {
        token
    }
}
