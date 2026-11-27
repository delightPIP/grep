import FeatureTerminalInterface
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
        case .signedOutEverywhere: "signedOutEverywhere"
        }
    }

    var bridgeFailureReason: String? {
        if case .failed(let reason) = self { reason.bridgeName } else { nil }
    }
}

extension CommandName {
    var bridgeName: String {
        switch self {
        case .keep: "keep"
        case .recent: "recent"
        case .seek: "seek"
        case .pick: "pick"
        case .handoff: "handoff"
        case .guide: "guide"
        case .about: "about"
        case .signOut: "signOut"
        case .revise: "revise"
        case .drop: "drop"
        case .revive: "revive"
        case .bin: "bin"
        }
    }
}

extension CommandFailure {
    var bridgeName: String {
        switch self {
        case .disconnected: "disconnected"
        case .timedOut: "timedOut"
        case .serverError: "serverError"
        case .clipboardDenied: "clipboardDenied"
        }
    }
}

/// API 값(`login_required`)이 아니라 Swift case 이름으로 넘긴다(view-state.ts `BlockedReason`).
extension BlockedReason {
    var bridgeName: String {
        switch self {
        case .loginRequired: "loginRequired"
        case .accessDenied: "accessDenied"
        case .disallowedURL: "disallowedURL"
        case .encrypted: "encrypted"
        case .noText: "noText"
        }
    }
}

extension ClipboardResult {
    init?(bridgeName: String) {
        switch bridgeName {
        case "copied": self = .copied
        case "denied": self = .denied
        default: return nil
        }
    }
}

extension FileUploadError {
    init?(bridgeName: String) {
        switch bridgeName {
        case "cancelled": self = .cancelled
        case "unreachable": self = .unreachable
        case "timedOut": self = .timedOut
        case "rejected": self = .rejected
        case "missingFile": self = .missingFile
        default: return nil
        }
    }
}
