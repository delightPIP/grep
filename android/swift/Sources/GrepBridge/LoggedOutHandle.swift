import FeatureLoggedOutAndroid
import FeatureLoggedOutInterface
import GrepCore

/// Kotlin 어댑터가 구현한다(`:feature:loggedout:adapter`).
public protocol LoggedOutViewBridge {
    /// `noticeKind`: `"cancelled"`, `"failed"`, `"expired"`, `"signedOut"`, or `nil`.
    /// `failureReason`: `"disconnected"`, `"timedOut"`, `"denied"`, or `nil`.
    func render(noticeKind: String?, failureReason: String?, isSigningIn: Bool)
}

/// Kotlin 뷰가 화면 트리의 `id`로 만들어 쥔다.
public final class LoggedOutScreenHandle: Sendable {
    private let screenID: Int64

    public init(screenID: Int64) {
        self.screenID = screenID
    }

    public func attach(view: any LoggedOutViewBridge) {
        nonisolated(unsafe) let view = view
        MainActor.assumeIsolated {
            screen?.attach { state in
                let (kind, reason) = Self.encodeNotice(state.notice)
                view.render(noticeKind: kind, failureReason: reason, isSigningIn: state.isSigningIn)
            }
        }
    }

    public func detach() {
        MainActor.assumeIsolated { screen?.detach() }
    }

    /// `provider`: `"google"` 또는 `"github"`.
    public func signInTapped(provider: String) {
        MainActor.assumeIsolated {
            guard let authProvider = AuthProvider(rawValue: provider) else { return }
            screen?.send(.signInTapped(authProvider))
        }
    }

    @MainActor private var screen: LoggedOutAndroidScreen? {
        controller?.screen(id: screenID, as: LoggedOutAndroidScreen.self)
    }

    private static func encodeNotice(_ notice: LoggedOutViewState.Notice?) -> (String?, String?) {
        guard let notice else { return (nil, nil) }
        switch notice {
        case .cancelled:
            return ("cancelled", nil)
        case .failed(let reason):
            let rawReason = switch reason {
            case .disconnected: "disconnected"
            case .timedOut: "timedOut"
            case .denied: "denied"
            }
            return ("failed", rawReason)
        case .expired:
            return ("expired", nil)
        case .signedOut:
            return ("signedOut", nil)
        }
    }
}
