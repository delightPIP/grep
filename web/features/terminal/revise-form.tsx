// `고치기` 편집 칸.
import { type KeyboardEvent, useEffect, useRef, useState } from "react";
import type { Revising } from "../../support/view-state";
import { Line } from "../../ui/grep";

type ReviseFormProps = {
  revising: Revising;
  onSubmit?: (number: number, title: string, summary: string) => void;
  onCancel?: () => void;
};

/**
 * `고치기` 편집(commands 3절 고치기, 화면 W24). 모달 없이 출력 안에 제목·`요약 (직접 고침)` 두 칸을 열고 첫 칸에 초점.
 * Enter 저장, Esc 취소, Tab은 브라우저 기본대로 다음 칸. 고친 값은 저장 전까지 이 칸만 들고 있다.
 */
export function ReviseForm({ revising, onSubmit, onCancel }: ReviseFormProps) {
  const [title, setTitle] = useState(revising.title);
  const [summary, setSummary] = useState(revising.summary);
  const titleRef = useRef<HTMLInputElement>(null);
  // 입력줄의 autoFocus가 뒤에 그려져 초점을 가져가므로, 그린 뒤 제목 칸으로 옮긴다.
  useEffect(() => titleRef.current?.focus(), []);

  function handleKeyDown(event: KeyboardEvent<HTMLInputElement>) {
    if (event.key === "Escape") {
      event.preventDefault();
      onCancel?.();
      return;
    }
    // 한글 조합을 끝내는 엔터는 저장이 아니다.
    if (event.key !== "Enter" || event.nativeEvent.isComposing) return;
    event.preventDefault();
    onSubmit?.(revising.number, title, summary);
  }

  return (
    <div className="gt-block gt-revise">
      <Line tone="info">{`고치기 ${revising.number}  ${revising.title}`}</Line>
      <label className="gt-field">
        <span className="gt-hint">제목</span>
        <input
          ref={titleRef}
          className="gt-field-input"
          type="text"
          autoComplete="off"
          spellCheck={false}
          value={title}
          onChange={(event) => setTitle(event.target.value)}
          onKeyDown={handleKeyDown}
        />
      </label>
      <label className="gt-field">
        <span className="gt-hint">요약 (직접 고침)</span>
        <input
          className="gt-field-input"
          type="text"
          autoComplete="off"
          spellCheck={false}
          value={summary}
          onChange={(event) => setSummary(event.target.value)}
          onKeyDown={handleKeyDown}
        />
      </label>
      <Line tone="info">Enter: 저장 · Esc: 취소 · Tab: 다음 칸</Line>
    </div>
  );
}
