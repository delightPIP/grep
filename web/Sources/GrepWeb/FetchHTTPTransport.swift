import GrepCore
import JavaScriptEventLoop
import JavaScriptKit

/// 브라우저 `fetch`로 보내는 전송 계층. 서버 주소(`baseURL`)는 여기서 붙인다(ADR-0011 결정 3).
/// 본문은 텍스트로 받아 UTF-8 바이트로 넘긴다. 이 API의 본문은 JSON이다.
/// `baseURL`이 다른 출처면 브라우저가 CORS를 적용한다. 거부되면 `fetch`가 네트워크 오류와 같은 `TypeError`로 거절해
/// `unreachable`로 끝난다. 원인은 브라우저 콘솔에만 남는다.
@MainActor
final class FetchHTTPTransport: HTTPTransport {
    /// 이 시간 안에 응답이 없으면 `응답 없음`으로 본다(COM-010, 08 6절 14번).
    static let timeoutMillis = 10_000
    private static let timeoutErrorName = "TimeoutError"

    private let baseURL: String

    init(baseURL: String) {
        self.baseURL = baseURL
    }

    func send(_ request: HTTPRequest) async throws(HTTPTransportError) -> HTTPResponse {
        // Task가 취소되면 요청도 끊는다. Wasm은 스레드가 하나라 취소 핸들러도 같은 스레드에서 돈다.
        nonisolated(unsafe) let abort = JSObject.global.AbortController.function!.new()
        let options = JSObject.global.Object.function!.new()
        options.method = .string(request.method.rawValue)
        options.signal = Self.signal(abortingWith: abort)
        let headers = JSObject.global.Object.function!.new()
        for (name, value) in request.headers {
            headers[name] = .string(value)
        }
        options.headers = .object(headers)
        if let body = request.body {
            options.body = .string(body)
        }
        let url = baseURL + request.path
        let result: Result<HTTPResponse, HTTPTransportError> = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard let fetched = JSObject.global.fetch.function!(url, options).object else {
                    continuation.resume(returning: .failure(.unreachable))
                    return
                }
                let status = StatusBox()
                _ = JSPromise(unsafelyWrapping: fetched)
                    .then(success: { response in
                        guard let response = response.object else { return .undefined }
                        status.code = response.status.number.map { Int($0) }
                        return response.text!()
                    })
                    .then(
                        success: { text in
                            if let code = status.code, let body = text.string {
                                continuation.resume(returning: .success(HTTPResponse(status: code, body: Array(body.utf8))))
                            } else {
                                continuation.resume(returning: .failure(.unreachable))
                            }
                            return .undefined
                        },
                        failure: { error in
                            let timedOut = error.object?.name.string == Self.timeoutErrorName
                            continuation.resume(returning: .failure(timedOut ? .timedOut : .unreachable))
                            return .undefined
                        }
                    )
            }
        } onCancel: {
            _ = abort.abort!()
        }
        // 끊긴 요청은 거절로 끝난다. 취소가 원인이면 취소로 알린다.
        if Task.isCancelled { throw .cancelled }
        return try result.get()
    }
}

extension FetchHTTPTransport {
    /// 취소 신호에 시간 제한을 합친다. `AbortSignal.any`·`timeout`이 없는 브라우저
    /// (Chrome 116, Safari 17.4, Firefox 124 미만)에서는 시간 제한 없이 취소 신호만 쓴다.
    private static func signal(abortingWith abort: JSObject) -> JSValue {
        let abortSignal = JSObject.global.AbortSignal.function!
        guard let any = abortSignal.any.function, let timeout = abortSignal.timeout.function else {
            return abort.signal
        }
        let signals = JSObject.global.Array.function!.new()
        _ = signals.push!(abort.signal, timeout(this: abortSignal, timeoutMillis))
        return any(this: abortSignal, signals)
    }
}

/// 첫 콜백이 읽은 상태 코드를 다음 콜백에 넘긴다.
private final class StatusBox {
    var code: Int?
}
