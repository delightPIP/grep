#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// 접근 토큰(JWT)의 `sub`(Supabase 사용자 ID)를 읽는다.
/// 서명은 확인하지 않는다. "만료 전과 같은 계정인가"를 비교하는 데만 쓰고(COM-009 규칙 3·4),
/// 권한 판정은 서버가 JWKS로 한다(ADR-BCK-006 결정 5).
public enum AccessTokenSubject {
    private struct Payload: Decodable {
        let sub: String
    }

    public static func read(from token: String) -> String? {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, let data = decodeBase64URL(String(parts[1])) else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: data).sub
    }

    private static func decodeBase64URL(_ text: String) -> Data? {
        var base64 = String(text.map { $0 == "-" ? "+" : $0 == "_" ? "/" : $0 })
        let remainder = base64.count % 4
        if remainder > 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        return Data(base64Encoded: base64)
    }
}
