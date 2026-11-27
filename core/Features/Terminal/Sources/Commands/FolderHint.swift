/// 폴더를 만들려는 입력(ARC-007 규칙 11·값). `폴더`·`mkdir`로 시작하면 뒤에 무엇이 와도 같은 안내를 보인다.
enum FolderHint {
    private static let prefixes = ["폴더", "mkdir"]

    static func matches(_ text: String) -> Bool {
        let trimmed = text.trimmingWhitespace().lowercased()
        return prefixes.contains { trimmed.hasPrefix($0) }
    }
}
