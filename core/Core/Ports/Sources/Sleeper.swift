/// 정한 시간만큼 기다린다. 폴링 주기(ARC-005 2초, COM-010 5초)를 테스트가 앞당길 수 있게 주입한다.
@MainActor
public protocol Sleeper: AnyObject {
    /// 시간이 지나거나 Task가 취소되면 돌아온다. 취소됐는지는 부른 쪽이 확인한다.
    func sleep(for duration: Duration) async
}

/// `Task.sleep`으로 기다린다. 웹(JavaScriptEventLoop)과 iOS 모두 이것을 쓴다.
@MainActor
public final class TaskSleeper: Sleeper {
    public init() {}

    public func sleep(for duration: Duration) async {
        try? await Task.sleep(for: duration)
    }
}
