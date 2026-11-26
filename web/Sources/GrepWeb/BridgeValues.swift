import FeatureLoggedInInterface
import FeatureLoggedOutInterface
import GrepCore

// 브리지를 건너는 문자열 값. `web/support/view-state.ts`, `web/auth/auth-service.ts`와 같은 이름을 쓴다.

extension SignInFailureReason {
    var bridgeName: String {
        switch self {
        case .disconnected: "disconnected"
        case .timedOut: "timedOut"
        case .denied: "denied"
        }
    }

    init?(bridgeName: String) {
        switch bridgeName {
        case "disconnected": self = .disconnected
        case "timedOut": self = .timedOut
        case "denied": self = .denied
        default: return nil
        }
    }
}

extension LoggedOutViewState.Notice {
    var bridgeKind: String {
        switch self {
        case .cancelled: "cancelled"
        case .failed: "failed"
        case .expired: "expired"
        case .signedOut: "signedOut"
        }
    }

    var bridgeFailureReason: String? {
        if case .failed(let reason) = self { reason.bridgeName } else { nil }
    }
}

extension LoggedInViewState.Line {
    var bridgeRow: TerminalLineRow {
        switch self {
        case .prompt(let text): TerminalLineRow(kind: "prompt", text: text)
        case .unknownCommand(let name): TerminalLineRow(kind: "unknownCommand", text: name)
        }
    }
}
