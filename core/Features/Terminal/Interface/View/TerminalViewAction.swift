import GrepCore
import RIBs

/// 뷰 → 코어.
public enum TerminalViewAction: Equatable, Sendable {
    /// 입력줄이 바뀌었다. 코어가 만료 때 보존할 줄을 알기 위해 받는다.
    case inputChanged(String)
    /// 엔터.
    case submitted(String)
    /// 입력줄에 링크·글을 붙여 넣었다. 붙여 넣기만 해도 저장한다(commands 3절 담기).
    case pasted(String)
    /// 파일을 끌어다 놓았다. 바이트는 `FilePort`가 `DroppedFile.id`로 올린다.
    case filesDropped([DroppedFile])
    /// 목록 맨 아래 `→ 더 보기`를 눌렀다.
    case moreRequested
    /// 0건 첫 화면의 `→ 샘플 8건으로 해 보기`. 누르면 바로 저장한다(ARC-010 규칙 2).
    case samplesRequested
    /// `고치기` 편집 칸에서 Enter로 저장했다.
    case reviseSubmitted(number: Int, title: String, summary: String)
    /// `고치기` 편집 칸에서 Esc로 취소했다.
    case reviseCancelled
    /// #168 보관함 탭을 열었다. 자동 묶음·묶음·찾아둔 검색·자료 첫 쪽을 받는다.
    case archiveOpen
    /// #168 보관함에서 거를 것을 골랐다.
    case archiveSelect(ArchiveFilter)
    /// #168 보관함 목록 맨 아래 `더 보기`.
    case archiveMore
    /// #168 설정 탭을 열었다. 계정과 AI 도구 연결을 받는다.
    case settingsOpen
}
