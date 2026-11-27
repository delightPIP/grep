import GrepCore
#if canImport(UIKit)
import UIKit
#endif

/// `UIPasteboard`로 구현한 클립보드 포트(COM-008).
@MainActor
public final class PasteboardClipboardPort: ClipboardPort {
    private let write: @MainActor (String) -> ClipboardResult

    public init() {
        self.write = { text in
            #if canImport(UIKit)
            UIPasteboard.general.string = text
            return .copied
            #else
            return .denied
            #endif
        }
    }

    /// 테스트용 주입 생성자.
    public init(write: @escaping @MainActor (String) -> ClipboardResult) {
        self.write = write
    }

    public func copy(_ text: String) async -> ClipboardResult {
        write(text)
    }
}
