import FeatureLoggedOutInterface
import FeatureLoggedOutUI
import GrepCore
import Observation
import RIBs
import RIBsSwiftUI
import SwiftUI

/// 로그인 피처의 어댑터를 만든다(ADR-0015).
@MainActor
public final class LoggedOutScreenFactory: LoggedOutViewFactory {
    public init() {}

    public func makeLoggedOutView() -> any LoggedOutViewContract { LoggedOutScreen() }
}

/// 코어 `LoggedOutViewContract`를 구현하고 상태를 풀어 순수 뷰(`FeatureLoggedOutUI`)에 넘긴다.
@MainActor
final class LoggedOutScreen: LoggedOutViewContract, SwiftUIRenderable {
    weak var listener: (any LoggedOutPresentableListener)?
    private let model = LoggedOutModel()

    func render(_ state: LoggedOutViewState) {
        model.state = state
    }

    func makeView() -> AnyView {
        AnyView(
            LoggedOutContent(model: model) { [weak self] action in
                self?.listener?.handle(action)
            }
        )
    }
}

@MainActor @Observable
final class LoggedOutModel {
    var state = LoggedOutViewState()
}

private struct LoggedOutContent: View {
    let model: LoggedOutModel
    let send: (LoggedOutViewAction) -> Void

    var body: some View {
        LoggedOutView(
            notice: model.state.notice.map(Self.mapNotice),
            isSigningIn: model.state.isSigningIn
        ) { choice in
            let provider: AuthProvider = switch choice {
            case .google: .google
            case .github: .github
            }
            send(.signInTapped(provider))
        }
    }

    private static func mapNotice(_ notice: LoggedOutViewState.Notice) -> LoggedOutNoticeKind {
        switch notice {
        case .cancelled:
            return .cancelled
        case .failed(let reason):
            return .failed(reason: mapFailureReason(reason))
        case .expired:
            return .expired
        case .signedOut, .signedOutEverywhere:
            return .signedOut
        }
    }

    private static func mapFailureReason(_ reason: SignInFailureReason) -> String {
        switch reason {
        case .disconnected: "연결 끊김"
        case .timedOut: "응답 없음"
        case .denied: "권한 거부"
        }
    }
}
