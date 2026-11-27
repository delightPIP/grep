/// `고르기 <번호…>`·`고르기 빼기 <번호…>`·`고르기 비우기`(commands 3절, #108). 자료 번호를 읽는다(ARC-001 규칙 11·값).
enum PickCommand {
    enum Parsed: Equatable {
        /// 친 순서, 같은 번호는 한 번만(ARC-001 값).
        case numbers([Int])
        /// `고르기 빼기 <번호…>` / `pick remove <번호…>`
        case unpick([Int])
        /// `고르기 비우기` / `pick clear`
        case clear
        /// 번호가 없다. `✗ 번호 없음`
        case missingArgument
        /// 양의 정수가 아닌 첫 낱말. `✗ 잘못된 번호: <입력>`
        case invalidNumber(String)
    }

    static func parse(_ argument: String) -> Parsed {
        let tokens = argument.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let first = tokens.first else { return .missingArgument }
        if (first == "비우기" || first == "clear") && tokens.count == 1 {
            return .clear
        }
        if first == "빼기" || first == "remove" {
            let rest = Array(tokens.dropFirst())
            guard !rest.isEmpty else { return .missingArgument }
            switch parseNumbers(rest) {
            case .numbers(let numbers): return .unpick(numbers)
            case .invalidNumber(let token): return .invalidNumber(token)
            default: return .missingArgument
            }
        }
        return parseNumbers(tokens)
    }

    private static func parseNumbers(_ tokens: [String]) -> Parsed {
        var numbers: [Int] = []
        for token in tokens {
            guard let number = number(from: token) else { return .invalidNumber(token) }
            if !numbers.contains(number) { numbers.append(number) }
        }
        return .numbers(numbers)
    }

    /// 숫자만으로 된 1 이상의 정수. 부호·소수·범위(`3-7`)는 받지 않는다.
    private static func number(from token: String) -> Int? {
        guard token.allSatisfy({ $0.isASCII && $0.isNumber }), let number = Int(token), number >= 1 else {
            return nil
        }
        return number
    }
}
