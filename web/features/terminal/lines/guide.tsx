// 안내·도움말 줄 렌더러.
import { useContext } from "react";
import { COMMAND_FAILURE_LABEL, COMMAND_LABEL } from "../format/words";
import { ListLines } from "./list";
import { ChipContext, CommandChip, Plain } from "../parts";
import type { CommandFailure, CommandName, ItemSummary } from "../../../support/view-state";
import { Banner, Line } from "../../../ui/grep";

/** ARC-001 사용자 문구의 예 */
export const PICK_EXAMPLE = "고르기 131 140";

/** 0건 뒤 최근 자료는 검색 결과처럼 읽히지 않게 머리줄을 단다(commands 6절, ARC-002 사용자 문구). */
/**
 * commands 5절 없는 명령. 가까운 명령(F17)이 있으면 고친 입력을 묻고, 없으면 도움말로 안내한다.
 * 제안 칩은 다른 명령 칩처럼 입력줄에 찍기만 한다. 엔터 한 번으로 제안을 실행하는 것은 코어가 맡는다(commands 5절 입력 받아 주기).
 */
export function UnknownCommandLines({ name, suggestion }: { name: string; suggestion: string | null }) {
  return (
    <>
      <Line tone="error">
        <b>없는 명령:</b> {name}
      </Line>
      <Plain>
        {"→ "}
        {suggestion === null ? (
          <>
            {"명령 목록: "}
            <CommandChip command="도움말" />
          </>
        ) : (
          <>
            <CommandChip command={suggestion} />?
          </>
        )}
      </Plain>
    </>
  );
}

export function CommandFailedLines({ command, reason, retry }: { command: CommandName; reason: CommandFailure; retry: string }) {
  return (
    <>
      <Line tone="error">{`${COMMAND_LABEL[command]} 안 됨: ${COMMAND_FAILURE_LABEL[reason]}`}</Line>
      <Plain>→ 다시: {retry}</Plain>
    </>
  );
}

/** 터미널 출력 맨 위의 두더지 머리. 로그인 화면과 같은 한 문장·표어다. */
function TerminalHead() {
  return <Banner lead="저장해 둔 링크·캡처·PDF를 찾아 AI 도구에 붙여 넣을 글로 복사" tagline="담기 → 찾기 → 넘기기" />;
}

/**
 * 자료가 있는 계정의 터미널 맨 위(시안 web-07). 머리 아래에 `· 자료 N건`과 `· 명령 전체: 도움말`을 둔다.
 * 건수는 지금 값이다. 받기 전이면 건수 줄을 뺀다.
 */
export function TerminalIntro({ itemCount }: { itemCount: number | null }) {
  return (
    <div className="gt-head">
      <TerminalHead />
      {itemCount !== null && <Line tone="info">자료 {itemCount.toLocaleString("ko-KR")}건</Line>}
      <Line tone="info">
        {"명령 전체: "}
        <CommandChip command="도움말" />
      </Line>
    </div>
  );
}

/** commands 6절 첫 화면(자료 0건). 명령 13줄 표는 보이지 않는다. */
/** ARC-010 규칙 2: 누르면 바로 저장. 두 번 눌러도 한 번만 저장하는 것(규칙 7)은 코어·서버가 지킨다. */
function SamplesChip() {
  const { requestSamples } = useContext(ChipContext);
  return (
    <button type="button" className="gt-chip" onClick={requestSamples}>
      샘플 8건으로 해 보기
    </button>
  );
}

/** ARC-010 규칙 4: 받은 번호 범위와 치우는 법을 한 줄씩, 이어서 `최근`과 같은 목록. */
export function SamplesSavedLines({ firstNumber, lastNumber, items }: { firstNumber: number; lastNumber: number; items: ItemSummary[] }) {
  const range = `${firstNumber}-${lastNumber}`;
  return (
    <>
      <Line tone="ok">{`샘플 ${lastNumber - firstNumber + 1}건 저장 (${range}번)`}</Line>
      <Line tone="info">
        {"치우려면: "}
        <CommandChip command={`버리기 ${range}`} />
      </Line>
      <ListLines items={items} hasMore={false} />
    </>
  );
}

export function WelcomeLines() {
  return (
    <>
      <TerminalHead />
      <Line tone="info">자료 0건</Line>
      <Plain>
        {"→ "}
        <SamplesChip />
        {" 또는 아래에 링크 붙여 넣기"}
      </Plain>
      <Line tone="info">
        {"명령 전체: "}
        <CommandChip command="도움말" />
      </Line>
    </>
  );
}

/** commands 2절 `도움말` 화면. 명령 18줄(한글·영문·뜻): 데모 13줄 + 휴지통 3줄(ARC-008, #96) + 열기·찾아두기(#131·#134). QA F-01 */
const GUIDE_ROWS: ReadonlyArray<readonly [string, string, string]> = [
  ["담기", "keep", "자료 저장"],
  ["최근", "recent", "최근 자료 목록"],
  ["찾기", "seek", "검색"],
  ["열기", "peek", "자료 자세히 보기"],
  ["찾아두기", "gather", "검색어 저장"],
  ["고르기", "pick", "번호로 선택"],
  ["넘기기", "handoff", "AI 도구용 글 복사"],
  ["묶음", "pack", "선택에 이름 붙이기"],
  ["고치기", "revise", "제목·요약 수정"],
  ["버리기", "drop", "삭제"],
  ["되살리기", "revive", "휴지통에서 돌리기"],
  ["휴지통", "bin", "휴지통 목록"],
  ["휴지통 비우기", "bin empty", "휴지통 영구 삭제"],
  ["가져오기", "bring", "북마크 파일 가져오기"],
  ["연결", "plug", "AI 도구 연결"],
  ["로그아웃", "signout", "로그아웃"],
  ["도움말", "guide", "명령 목록"],
  ["설명", "about", "명령 설명"],
];

export function GuideLines() {
  return (
    <>
      <Plain>저장: 링크·글 붙여 넣기, 파일 끌어다 놓기. 명령: 한글·영문 같음</Plain>
      {GUIDE_ROWS.map(([name, english, meaning]) => (
        <div key={name} className="gt-line gt-guide-row">
          <span className="gt-guide-name">{name}</span>
          <span className="gt-hint">{english}</span>
          <span>{meaning}</span>
        </div>
      ))}
      <Plain>
        {"→ 예: "}
        <CommandChip command="찾기 결제 | 넘기기" />
        {" · 자세히: "}
        <CommandChip command="설명 찾기" />
      </Plain>
    </>
  );
}
