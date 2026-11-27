import FeatureLoggedOut
import FeatureLoggedOutAdapter
import FeatureLoggedOutInterface
import GrepCore
import GrepCoreTesting
import Observation
import RIBs
import RIBsSwiftUI
import SwiftUI

/// 로그인 피처만 띄우는 Example 앱. 시나리오 버튼으로 ACC-001 상태(기본·취소·실패·만료·로그아웃·성공)를 확인한다.
@main
struct LoggedOutExampleApp: App {
    @State private var harness = LoggedOutExampleHarness()

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 0) {
                RIBSlotView(slot: harness.slot)
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text(harness.lastEvent)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("exampleEvent")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            scenarioButton("첫 화면") { harness.start(notice: nil, nextResult: .success) }
                            scenarioButton("만료") { harness.start(notice: .expired, nextResult: .success) }
                            scenarioButton("로그아웃") { harness.start(notice: .signedOut, nextResult: .success) }
                            scenarioButton("취소") { harness.nextResult = .cancelled }
                            scenarioButton("연결 끊김") { harness.nextResult = .failed(.disconnected) }
                            scenarioButton("응답 없음") { harness.nextResult = .failed(.timedOut) }
                            scenarioButton("권한 거부") { harness.nextResult = .failed(.denied) }
                        }
                    }
                }
                .padding(12)
                .background(.bar)
            }
            .onAppear { harness.startIfNeeded() }
        }
    }

    private func scenarioButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .controlSize(.small)
    }
}

@MainActor @Observable
final class LoggedOutExampleHarness: LoggedOutListener, LoggedOutDependency {
    let slot = RIBScreenSlot()
    @ObservationIgnored private let exampleAuth = ExampleAuthService()
    var authService: any AuthService { exampleAuth }
    var nextResult: SignInResult {
        get { exampleAuth.nextResult }
        set { exampleAuth.nextResult = newValue }
    }
    private(set) var lastEvent = "부모 이벤트 없음"
    @ObservationIgnored private let parent = TestParentRouter()
    @ObservationIgnored private var currentRouter: (any ViewableRouting)?

    func startIfNeeded() {
        guard currentRouter == nil else { return }
        start(notice: nil, nextResult: .success)
    }

    func start(notice: LoggedOutViewState.Notice?, nextResult: SignInResult) {
        if let existing = currentRouter {
            parent.detach(existing)
            slot.hide(existing.viewControllable)
            currentRouter = nil
        }
        exampleAuth.nextResult = nextResult
        let router = LoggedOutBuilder(dependency: self, viewFactory: LoggedOutScreenFactory())
            .build(listener: self, notice: notice)
        parent.attach(router)
        slot.show(router.viewControllable)
        currentRouter = router
        lastEvent = "시작(notice: \(String(describing: notice)))"
    }

    func didSignIn() {
        lastEvent = "didSignIn() 수신"
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
