import GrepData
import TerminalDomain

/// `담기 <링크 또는 글>`(commands 3절). 저장 요청 본문을 정한다.
enum KeepCommand {
    /// COM-001 값: `http`·`https`만 링크로 저장한다. 그 밖의 스킴과 공백이 든 글은 글로 저장한다.
    private static let linkPrefixes = ["http://", "https://"]

    static func request(for argument: String) -> ItemsAPI.SaveRequest {
        let lowered = argument.lowercased()
        let isLink = !argument.contains(where: \.isWhitespace) && linkPrefixes.contains(where: lowered.hasPrefix)
        return isLink ? .link(url: argument) : .text(argument)
    }
}
