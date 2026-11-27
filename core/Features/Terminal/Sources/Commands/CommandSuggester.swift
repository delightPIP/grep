import FeatureTerminalInterface

/// 명령 오타 제안(#118, commands.md 207줄). 한글 자모 거리와 영문 문자 편집 거리로 가장 가까운 명령을 찾는다.
enum CommandSuggester {
    private static let koreanCommands = [
        "담기", "최근", "찾기", "고르기", "넘기기", "도움말", "설명", "로그아웃", "버리기", "되살리기", "휴지통", "고치기", "묶음", "열기", "찾아두기", "가져오기", "연결",
    ]
    private static let englishCommands = [
        "keep", "recent", "seek", "pick", "handoff", "guide", "about", "signout", "drop", "revive", "bin", "revise", "pack", "peek", "gather", "bring", "plug",
    ]
    private static let excludedWords: Set<String> = ["login", "logout"]

    /// 오타에 가까운 명령이 있으면 인자를 이어 붙인 전체 입력 문자열을 돌려준다(예: `"찾기 결제"`).
    static func suggest(word: String, argument: String) -> String? {
        let lower = word.lowercased()
        guard !lower.isEmpty, !excludedWords.contains(lower) else { return nil }

        let matched: String?
        if word.unicodeScalars.allSatisfy({ $0.isASCII }) {
            matched = bestEnglishMatch(for: lower)
        } else {
            matched = bestKoreanMatch(for: word)
        }
        guard let matched else { return nil }
        return argument.isEmpty ? matched : "\(matched) \(argument)"
    }

    private static func bestKoreanMatch(for word: String) -> String? {
        let target = decomposeHangul(word)
        guard !target.isEmpty else { return nil }
        var best: (command: String, distance: Int)?
        for candidate in koreanCommands {
            let decomposed = decomposeHangul(candidate)
            let distance = levenshtein(target, decomposed)
            let limit = candidate.count <= 2 ? 2 : 3
            guard distance >= 1, distance <= limit else { continue }
            if best == nil || distance < best!.distance {
                best = (candidate, distance)
            }
        }
        return best?.command
    }

    private static func bestEnglishMatch(for word: String) -> String? {
        let target = Array(word)
        var best: (command: String, distance: Int)?
        for candidate in englishCommands {
            let chars = Array(candidate)
            let distance = levenshtein(target, chars)
            let limit = candidate.count <= 3 ? 1 : 2
            guard distance >= 1, distance <= limit else { continue }
            if best == nil || distance < best!.distance {
                best = (candidate, distance)
            }
        }
        return best?.command
    }

    /// 한글 완성형 음절(U+AC00...U+D7A3)을 초성·중성·종성 정수로 분해한다.
    private static func decomposeHangul(_ text: String) -> [UInt32] {
        var result: [UInt32] = []
        for scalar in text.unicodeScalars {
            let value = scalar.value
            if value >= 0xAC00, value <= 0xD7A3 {
                let offset = value - 0xAC00
                let choseong = offset / (21 * 28)
                let jungseong = (offset % (21 * 28)) / 28
                let jongseong = offset % 28
                result.append(0x1100 + choseong)
                result.append(0x1161 + jungseong)
                if jongseong > 0 {
                    result.append(0x11A7 + jongseong)
                }
            } else {
                result.append(value)
            }
        }
        return result
    }

    private static func levenshtein<T: Equatable>(_ a: [T], _ b: [T]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        var curr = Array(repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            curr[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                curr[j] = min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost)
            }
            swap(&prev, &curr)
        }
        return prev[b.count]
    }
}
