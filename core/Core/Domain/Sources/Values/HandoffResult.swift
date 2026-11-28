
/// 서버 `POST /handoff` 결과(api/openapi.yaml `Handoff`).
public struct HandoffResult: Equatable, Sendable {
    public let items: [ItemRef]
    /// `넘기기 <묶음>`이면 그 이름(계약 2). 아니면 nil.
    public let bundle: String?
    /// 묶음에서 휴지통·영구 삭제로 빠진 수 `! 빠진 자료 N건 (삭제됨)`.
    public let removedCount: Int
    /// 줄바꿈을 포함한 글자 수.
    public let charCount: Int
    public let missingSummaryCount: Int
    /// 클립보드에 넣은 글 전체. `펼치기`로 보인다.
    public let text: String

    public init(
        items: [ItemRef],
        bundle: String? = nil,
        removedCount: Int = 0,
        charCount: Int,
        missingSummaryCount: Int,
        text: String
    ) {
        self.items = items
        self.bundle = bundle
        self.removedCount = removedCount
        self.charCount = charCount
        self.missingSummaryCount = missingSummaryCount
        self.text = text
    }
}
