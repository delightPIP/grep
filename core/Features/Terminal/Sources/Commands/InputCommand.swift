import FeatureTerminalInterface

/// 입력줄 한 줄을 명령 이름과 인자로 나눈다. 명령 이름은 한글·영문을 같게 본다(commands 2절).
struct InputCommand: Equatable {
    /// 첫 낱말 그대로. 없는 명령 줄에 쓴다.
    let word: String
    /// 아는 명령이면 그 이름.
    let name: CommandName?
    /// 첫 낱말 뒤의 글. 앞뒤 공백을 지운다.
    let argument: String

    /// 빈 줄이면 nil.
    init?(_ text: String) {
        let trimmed = text.drop(while: \.isWhitespace)
        guard let end = trimmed.firstIndex(where: \.isWhitespace) ?? (trimmed.isEmpty ? nil : trimmed.endIndex) else {
            return nil
        }
        word = String(trimmed[..<end])
        name = Self.name(for: word)
        argument = String(trimmed[end...]).trimmingWhitespace()
    }

    /// 한글·영문 명령 이름을 같게 본다. 아는 명령이 아니면 nil.
    static func name(for word: String) -> CommandName? {
        names[word]
    }

    /// commands 2절 표. `logout`·`login`은 받지 않는다(ACC-001 값).
    private static let names: [String: CommandName] = [
        "담기": .keep, "keep": .keep,
        "최근": .recent, "recent": .recent,
        "찾기": .seek, "seek": .seek,
        "고르기": .pick, "pick": .pick,
        "넘기기": .handoff, "handoff": .handoff,
        "도움말": .guide, "guide": .guide,
        "설명": .about, "about": .about,
        "로그아웃": .signOut, "signout": .signOut,
        "버리기": .drop, "drop": .drop,
        "되살리기": .revive, "revive": .revive,
        "휴지통": .bin, "bin": .bin,
        "고치기": .revise, "revise": .revise,
        "묶음": .pack, "pack": .pack,
        "열기": .peek, "peek": .peek,
    ]
}

extension String {
    func trimmingWhitespace() -> String {
        String(drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
    }
}
