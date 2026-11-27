import FeatureTerminalInterface

/// `묶음`·`묶음 <이름>`·`묶음 <이름> 빼기 <번호…>`·`묶음 <이름> 지우기`(commands 3절, ARC-003).
enum BundleCommand {
    enum Parsed: Equatable {
        case list
        /// 선택이 있으면 넣기, 없으면 보기(ARC-003 규칙 4·5).
        case named(String)
        case remove(name: String, numbers: [Int])
        case delete(String)
        case invalidName(BundleNameProblem)
        /// `빼기` 뒤 번호가 없다.
        case missingNumbers
        case invalidNumber(String)
    }

    static let removeWord = "빼기"
    static let deleteWord = "지우기"
    private static let maxNameLength = 20

    static func parse(_ argument: String) -> Parsed {
        let tokens = argument.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let name = tokens.first else { return .list }
        if tokens.count >= 2 && tokens[1] == removeWord {
            return remove(name: name, numberTokens: tokens.dropFirst(2))
        }
        if tokens.count == 2 && tokens[1] == deleteWord {
            return problem(of: name).map(Parsed.invalidName) ?? .delete(name)
        }
        // 그 밖에 낱말이 더 있으면 띄어쓰기가 든 이름이다.
        let whole = tokens.count == 1 ? name : argument.trimmingWhitespace()
        return problem(of: whole).map(Parsed.invalidName) ?? .named(whole)
    }

    /// 이름 규칙(ARC-003 값). 금지 이름을 먼저 본다(`#결제`는 글자 규칙에도 걸리지만 금지 이름 문구가 더 정확하다).
    static func problem(of name: String) -> BundleNameProblem? {
        if name.hasPrefix("#") || name == removeWord || name == deleteWord
            || (!name.isEmpty && name.allSatisfy { $0.isASCII && $0.isNumber }) {
            return .reserved
        }
        guard (1...maxNameLength).contains(name.count), name.unicodeScalars.allSatisfy(isAllowed) else {
            return .format
        }
        return nil
    }

    private static func remove(name: String, numberTokens: ArraySlice<String>) -> Parsed {
        if let problem = problem(of: name) { return .invalidName(problem) }
        switch PickCommand.parse(numberTokens.joined(separator: " ")) {
        case .numbers(let numbers): return .remove(name: name, numbers: numbers)
        case .invalidNumber(let token): return .invalidNumber(token)
        case .missingArgument: return .missingNumbers
        case .unpick, .clear: return .invalidNumber(numberTokens.first ?? "")
        }
    }

    /// 한글 음절, 영문, 숫자, `-`, `_`.
    private static func isAllowed(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0xAC00...0xD7A3: true
        case 0x30...0x39, 0x41...0x5A, 0x61...0x7A: true
        case 0x2D, 0x5F: true
        default: false
        }
    }
}
