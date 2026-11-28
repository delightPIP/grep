import FeatureTerminalInterface
import FeatureTerminalUI
import Foundation
import GrepCore

// 명령 줄, 명령 오류, 첫 화면·도움말·설명, 연결 회복.
extension TerminalStateMapper {
    private static let guideRows: [TerminalGuideRow] = [
        TerminalGuideRow(name: "담기", english: "keep", meaning: "자료 저장"),
        TerminalGuideRow(name: "최근", english: "recent", meaning: "최근 자료 목록"),
        TerminalGuideRow(name: "찾기", english: "seek", meaning: "검색"),
        TerminalGuideRow(name: "고르기", english: "pick", meaning: "번호로 선택"),
        TerminalGuideRow(name: "넘기기", english: "handoff", meaning: "AI 도구용 글 복사"),
        TerminalGuideRow(name: "묶음", english: "pack", meaning: "선택에 이름 붙이기"),
        TerminalGuideRow(name: "고치기", english: "revise", meaning: "제목·요약 수정"),
        TerminalGuideRow(name: "버리기", english: "drop", meaning: "삭제"),
        TerminalGuideRow(name: "되살리기", english: "revive", meaning: "휴지통에서 돌리기"),
        TerminalGuideRow(name: "휴지통", english: "bin", meaning: "휴지통 목록"),
        TerminalGuideRow(name: "휴지통 비우기", english: "bin empty", meaning: "휴지통 영구 삭제"),
        TerminalGuideRow(name: "가져오기", english: "bring", meaning: "북마크 파일 가져오기"),
        TerminalGuideRow(name: "연결", english: "plug", meaning: "AI 도구 연결"),
        TerminalGuideRow(name: "로그아웃", english: "signout", meaning: "로그아웃"),
        TerminalGuideRow(name: "도움말", english: "guide", meaning: "명령 목록"),
        TerminalGuideRow(name: "설명", english: "about", meaning: "명령 설명"),
    ]

    static func mapIntroLine(_ line: TerminalViewState.Line, failed: Bool) -> [TerminalOutputBlockLine] {
        switch line {
        case .prompt(let text):
            return [.prompt(command: text, failed: failed)]
        case .unknownCommand(let name, _):
            return [.status(tone: .error, boldPrefix: "없는 명령:", body: " \(name)")]
        case .missingArgument(let command, _):
            switch command {
            case .keep:
                return [.status(tone: .error, boldPrefix: nil, body: "저장할 것 없음  예: 담기 https://…")]
            case .seek:
                return [.status(tone: .error, boldPrefix: nil, body: "검색어 없음  예: 찾기 결제")]
            case .pick:
                return [.status(tone: .error, boldPrefix: nil, body: "번호 없음  예: 고르기 131")]
            default:
                return []
            }
        case .missingTag:
            return [.status(tone: .error, boldPrefix: nil, body: "태그 없음  예: 찾기 #결제")]
        case .cancelled:
            return [.status(tone: .info, boldPrefix: nil, body: "취소됨")]
        case .commandFailed(let command, let reason, let retry):
            return [
                .status(tone: .error, boldPrefix: nil, body: "\(TerminalTextFormat.commandLabel(command)) 안 됨: \(TerminalTextFormat.commandFailureLabel(reason))"),
                .commandHint(prefix: "→ 다시: ", command: retry, suffix: ""),
            ]
        case .welcome:
            return [.welcome]
        case .guide:
            return [.guide(rows: guideRows)]
        case .about(let command):
            return [.status(tone: .info, boldPrefix: "\(TerminalTextFormat.commandLabel(command))", body: "  \(aboutDescription(command))")]
        case .reconnected:
            return [.status(tone: .ok, boldPrefix: nil, body: "연결됨")]
        default:
            return []
        }
    }

    private static func aboutDescription(_ command: CommandName) -> String {
        switch command {
        case .keep: "링크·글 저장  예: 담기 https://…"
        case .recent: "최근 자료 목록  예: 최근"
        case .seek: "검색어·#태그 검색  예: 찾기 결제 #sdk"
        case .pick: "번호로 자료 선택  예: 고르기 131 140"
        case .handoff: "선택한 자료를 AI 도구용 글로 복사  예: 넘기기"
        case .guide: "전체 명령 목록  예: 도움말"
        case .about: "명령 사용법 안내  예: 설명 찾기"
        case .signOut: "이 기기의 세션 종료  예: 로그아웃"
        case .revise: "제목·요약 수정, 태그 지우기  예: 고치기 131 -#위젯"
        case .drop: "자료를 휴지통으로  예: 버리기 131, 버리기 1-8"
        case .revive: "휴지통에서 돌리기  예: 되살리기 131"
        case .bin: "휴지통 목록·비우기  예: 휴지통, 휴지통 비우기"
        case .pack: "선택한 자료를 묶음에 넣기·보기  예: 묶음 결제조사"
        case .peek: "자료 하나 자세히 보기  예: 열기 131"
        case .gather: "검색어를 저장해 자료 모으기  예: 찾아두기 텀블러 캠페인"
        case .bring: "북마크 파일의 링크 한 번에 저장  예: 가져오기"
        case .plug: "AI 도구 연결 주소·목록  예: 연결, 연결 끊기 1"
        }
    }
}
