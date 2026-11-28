import GrepDomain

/// 데모 범위 명령(commands 2절). 한글·영문 이름은 코어가 해석한다.
public enum CommandName: Equatable, Sendable, CaseIterable {
    /// `담기`(keep)
    case keep
    /// `최근`(recent)
    case recent
    /// `찾기`(seek)
    case seek
    /// `고르기`(pick)
    case pick
    /// `넘기기`(handoff)
    case handoff
    /// `도움말`(guide)
    case guide
    /// `설명`(about)
    case about
    /// `로그아웃`(signout)
    case signOut
    /// `고치기`(revise)
    case revise
    /// `버리기`(drop)
    case drop
    /// `되살리기`(revive)
    case revive
    /// `휴지통`(bin)
    case bin
    /// `묶음`(pack)
    case pack
    /// `열기`(peek)
    case peek
    /// `찾아두기`(gather)
    case gather
    /// `가져오기`(bring)
    case bring
    /// `연결`(plug)
    case plug
}
