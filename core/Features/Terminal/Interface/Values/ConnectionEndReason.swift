import GrepCore

/// `! 연결 끊김: <AI 도구> (<이유>)` 이유(ACC-002 규칙 11).
public enum ConnectionEndReason: String, Equatable, Sendable, Codable {
    case expired
    case revoked
}
