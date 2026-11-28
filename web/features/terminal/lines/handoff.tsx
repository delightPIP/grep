// 고르기·넘기기 줄 렌더러.
import { useEffect, useRef, useState } from "react";
import { charCountText } from "../format/size";
import { titles } from "../format/title";
import { COMMAND_FAILURE_LABEL } from "../format/words";
import { CommandChip, NumberCell, Plain } from "../parts";
import type { CommandFailure, HandoffResult, ItemRef } from "../../../support/view-state";
import { Line } from "../../../ui/grep";

/** commands 6절 고르기. */
export function PickedLines({ items }: { items: ItemRef[] }) {
  return (
    <>
      <Line tone="ok">{`선택 ${items.length}건  ${titles(items)}`}</Line>
      <Plain>
        {"→ "}
        <CommandChip command="넘기기" />
        {" 또는 "}
        <CommandChip command="묶음 ">묶음 &lt;이름&gt;</CommandChip>
      </Plain>
    </>
  );
}

/** 넘긴 자료마다 `<번호>  <제목>` 한 줄. */
function ItemRefRows({ items }: { items: ItemRef[] }) {
  return (
    <>
      {items.map((ref) => (
        <div key={ref.number} className="gt-line gt-row">
          <NumberCell number={ref.number} />
          <span>{ref.title}</span>
        </div>
      ))}
    </>
  );
}

/**
 * 넘긴 글 전체. 터미널 글꼴이 아닌 읽기 글꼴로 줄바꿈을 그대로 보인다(시안 Handoff).
 * selectAll: 클립보드 거부 때 전체를 선택해 둔다(COM-008 규칙 6). 입력줄에 초점이 있으면 복사 키가 입력줄을 복사하므로 미리보기로 초점을 옮긴다.
 */
export function Preview({ text, selectAll = false }: { text: string; selectAll?: boolean }) {
  const ref = useRef<HTMLPreElement>(null);
  useEffect(() => {
    const preview = ref.current;
    if (!selectAll || preview === null) return;
    preview.focus();
    window.getSelection()?.selectAllChildren(preview);
  }, [selectAll]);
  return (
    <pre ref={ref} className="gt-preview" tabIndex={selectAll ? -1 : undefined}>
      {text}
    </pre>
  );
}

/** COM-008 값: 6건부터 묻고, 11건부터 `앞10`을 더한다. */
export const HANDOFF_DIRECT_LIMIT = 5;

export const HANDOFF_FIRST_LIMIT = 10;

/** COM-008 값: 직접 복사 키. 터치 기기 문구는 AI 제안(PO 확인 전). */
function copyKeyHint(): string {
  if (typeof window.matchMedia === "function" && window.matchMedia("(hover: none) and (pointer: coarse)").matches) {
    return "길게 눌러 복사";
  }
  return /mac|iphone|ipad/i.test(navigator.platform) ? "⌘C" : "Ctrl+C";
}

/** COM-008 넘기기 실패. 선택은 풀지 않는다(코어). 클립보드 거부만 펼친 미리보기와 직접 복사 키를 보인다. */
export function HandoffFailedLines({ reason, preview }: { reason: CommandFailure; preview: string | null }) {
  const isDenied = reason === "clipboardDenied";
  return (
    <>
      <Line tone="error">{`복사 안 됨: ${COMMAND_FAILURE_LABEL[reason]}  선택은 남겨 둠`}</Line>
      {isDenied && preview !== null && <Preview text={preview} selectAll />}
      <Plain>
        {isDenied ? `→ 직접 복사: ${copyKeyHint()} · 다시: ` : "→ "}
        <CommandChip command="넘기기" />
      </Plain>
    </>
  );
}

/** commands 6절 넘기기, 넘길 글 형식 3절. `펼치기`는 화면 칩이라 누르면 바로 펼친다. */
export function HandedOffLines({ result }: { result: HandoffResult }) {
  const [isExpanded, setExpanded] = useState(false);
  return (
    <>
      {/* ARC-003 규칙 10. 시안 Bundles ④는 복사됨 앞에 둔다. */}
      {(result.removedCount ?? 0) > 0 && <Line tone="warn">{`빠진 자료 ${result.removedCount}건 (삭제됨)`}</Line>}
      <Line tone="ok">{`복사됨  ${result.items.length}건 · ${charCountText(result.charCount)} (제목·출처·저장 시각·요약)`}</Line>
      <ItemRefRows items={result.items} />
      {result.missingSummaryCount > 0 && <Line tone="warn">{`요약 없음 ${result.missingSummaryCount}건`}</Line>}
      <Line tone="info">
        {"미리보기: "}
        <button type="button" className="gt-chip" aria-expanded={isExpanded} onClick={() => setExpanded(!isExpanded)}>
          {isExpanded ? "접기" : "펼치기"}
        </button>
      </Line>
      {isExpanded && <Preview text={result.text} />}
      <Line tone="info">클립보드에 있음 → AI 도구 입력창에 붙여 넣기</Line>
    </>
  );
}
