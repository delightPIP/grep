// 터미널 줄들이 같이 쓰는 칩·칸·기호 없는 줄.
import { createContext, Fragment, type ReactNode, useContext } from "react";

/**
 * 출력 안의 명령 칩·자료 번호가 쓰는 것(commands 6절 출력 원칙).
 * insert: 누르면 그 명령을 입력줄에 찍기만 한다(엔터로 실행). selected: 목록 행 `▸` 표시용 고른 번호.
 */
/** requestSamples: 화면 칩 `샘플 8건으로 해 보기`. 명령 칩과 달리 입력줄을 거치지 않는다. */
export type TerminalChips = { insert: (command: string) => void; selected: ReadonlySet<number>; requestSamples?: () => void };

export const ChipContext = createContext<TerminalChips>({ insert: () => {}, selected: new Set() });

/** 명령 칩. 누르면 입력줄에 찍힌다. 화면 칩(`더 보기`·`펼치기`)과 달리 바로 실행하지 않는다. */
export function CommandChip({ command, children }: { command: string; children?: ReactNode }) {
  const { insert } = useContext(ChipContext);
  return (
    <button type="button" className="gt-chip" onClick={() => insert(command)}>
      {children ?? command}
    </button>
  );
}

/** 자료 번호 칸. 누르면 `고르기 <번호>`, 이미 고른 자료면 `고르기 빼기 <번호>`(ARC-011 규칙 13). 고른 자료면 앞에 `▸`(commands 6절). */
export function NumberCell({ number }: { number: number }) {
  const { insert, selected } = useContext(ChipContext);
  return (
    <span className="gt-row-num">
      {selected.has(number) && <span aria-label="선택됨">▸</span>}
      <button type="button" className="gt-num-chip" onClick={() => insert(selected.has(number) ? `고르기 빼기 ${number}` : `고르기 ${number}`)}>
        {number}
      </button>
    </span>
  );
}

/** 기호 칸 없는 줄. 자료 한 줄과 `→` 다음 행동, 흐린 `· 요약 생성 중`. */
export function Plain({ dim = false, children }: { dim?: boolean; children: ReactNode }) {
  return (
    <div className={dim ? "gt-line gt-hint" : "gt-line"}>
      <span className="gt-line-text">{children}</span>
    </div>
  );
}

/** commands 6절 더 보기. 다음 쪽은 코어가 받는다. */
export function MoreChip({ onMoreRequested }: { onMoreRequested?: () => void }) {
  return (
    <Plain>
      {"→ "}
      <button type="button" className="gt-chip" onClick={onMoreRequested}>
        더 보기
      </button>
    </Plain>
  );
}

/** 이름 목록 한 줄 `<이름>  N건`(묶음·찾아둔 것). 이름을 누르면 그 명령이 찍힌다(commands 6절 출력 원칙). */
export function NameCountRow({ name, count, command }: { name: string; count: number; command: string }) {
  return (
    <div className="gt-line gt-name-row">
      <CommandChip command={command}>{name}</CommandChip>
      <span className="gt-hint">{`${count}건`}</span>
    </div>
  );
}

/** 칩 여럿을 한 칸 띄어 잇는다. */
export function ChipList({ commands }: { commands: ReadonlyArray<readonly [label: string, command: string]> }) {
  return (
    <>
      {commands.map(([label, command], index) => (
        <Fragment key={command}>
          {index > 0 && " "}
          <CommandChip command={command}>{label}</CommandChip>
        </Fragment>
      ))}
    </>
  );
}
