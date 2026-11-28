import FeatureTerminalInterface
import FeatureTerminalUI
import Foundation
import GrepCore

// 모든 기기 로그아웃 확인(ACC-002).
extension TerminalStateMapper {
    static func mapSignOutEverywhereLine(_ line: TerminalViewState.Line) -> [TerminalOutputBlockLine] {
        guard case .signOutEverywhereConfirm(let connectionCount) = line else { return [] }
        // ACC-002 사용자 문구. 답은 확인 시트의 낱말 버튼으로 받는다(MOB-002 규칙 4).
        return [.status(tone: .warn, boldPrefix: "로그아웃?", body: signOutEverywhereBody(connectionCount))]
    }

    /// ACC-002 사용자 문구. 끊길 AI 도구 연결이 있으면 `· AI 도구 연결 N개`, 없거나 모르면 그 칸을 뺀다(웹과 같음).
    static func signOutEverywhereBody(_ connectionCount: Int?) -> String {
        let connections = connectionCount.flatMap { $0 > 0 ? " · AI 도구 연결 \($0)개" : nil } ?? ""
        return " 모든 기기\(connections) (다른 기기는 최대 1시간 뒤)"
    }
}
