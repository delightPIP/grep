import GrepAndroid

/// Kotlin이 구현한다(`:feature:loggedin:adapter`의 `SwiftArchiveItemLoader`).
public protocol ArchivePageCallback {
    /// `ArchivePageEncoder`가 만든 UTF-8 JSON 문자열을 받는다.
    func complete(resultJson: String)
}

/// 보관함 목록 한 쪽을 불러온다. `SwiftBridge.installPlatformPorts`가 넣은 HTTP·인증 포트를 함께 쓴다.
public final class ArchiveLoaderHandle: Sendable {
    public init() {}

    public func loadPage(limit: Int32, cursor: String?, callback: any ArchivePageCallback) {
        nonisolated(unsafe) let callback = callback
        MainActor.assumeIsolated {
            guard let authService, let httpTransport else {
                callback.complete(resultJson: ArchivePageEncoder.encode(.failed(.serverError)))
                return
            }
            let loader = HTTPArchiveItemLoader(authService: authService, httpTransport: httpTransport)
            Task { @MainActor in
                let outcome = await loader.loadPage(limit: Int(limit), cursor: cursor)
                callback.complete(resultJson: ArchivePageEncoder.encode(outcome))
            }
        }
    }
}
