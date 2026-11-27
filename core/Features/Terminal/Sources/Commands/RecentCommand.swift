/// `최근 [개수]`(commands 3절). 한 쪽에 받을 건수를 정한다.
enum RecentCommand {
    /// 개수를 생략했을 때(commands 3절).
    private static let defaultLimit = 10
    /// 서버가 한 쪽에 주는 최대 건수(api/openapi.yaml `Limit`).
    private static let maxLimit = 50

    /// shortcut: 시점 인자(`최근 지난달`, F22)는 아직 받지 않고 기본 건수로 본다. 시점을 구현하는 이슈에서 나눈다.
    static func limit(for argument: String) -> Int {
        guard let count = Int(argument), count >= 1 else { return defaultLimit }
        return min(count, maxLimit)
    }
}
