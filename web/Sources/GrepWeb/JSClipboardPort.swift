import GrepCore
import JavaScriptKit

/// JS가 구현한 클립보드(`web/ports/clipboard-port.ts`의 `ClipboardPort`)를 코어의 `ClipboardPort`로 잇는다.
@MainActor
final class JSClipboardPort: ClipboardPort {
    private let port: JSObject

    init(port: JSObject) {
        self.port = port
    }

    /// 계약과 다른 값이 오거나 프로미스가 거절되면 넣지 못한 것으로 본다.
    func copy(_ text: String) async -> ClipboardResult {
        await JSPromiseValue.await(port.copy!(text), rejected: .denied) { value in
            value.string.flatMap(ClipboardResult.init(bridgeName:)) ?? .denied
        }
    }
}
