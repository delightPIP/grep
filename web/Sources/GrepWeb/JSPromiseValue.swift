import JavaScriptKit

/// JS 호출 결과를 기다린다. 프로미스가 아니면 그 값을 바로 쓴다.
/// `JSPromise.value`는 메인 액터 밖에서 도는 프로퍼티라 `JSValue`가 액터 경계를 넘는다.
/// 그래서 프로미스 콜백 안에서 `Sendable`한 결과로 바꿔 continuation으로 돌려준다.
@MainActor
enum JSPromiseValue {
    static func await<T: Sendable>(_ value: JSValue, rejected: T, map: @escaping (JSValue) -> T) async -> T {
        guard let promise = JSObject.global.Promise.function!.resolve!(value).object else { return rejected }
        return await withCheckedContinuation { continuation in
            _ = JSPromise(unsafelyWrapping: promise).then(
                success: { resolved in
                    continuation.resume(returning: map(resolved))
                    return .undefined
                },
                failure: { _ in
                    continuation.resume(returning: rejected)
                    return .undefined
                }
            )
        }
    }
}
