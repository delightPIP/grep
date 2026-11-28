// 터미널 테스트가 같이 쓰는 렌더 도우미와 자료 만들기.
import { render, screen } from "@testing-library/react";
import { vi } from "vitest";
import type { ItemSummary, LoggedInState } from "../../support/view-state";
import { LoggedInView } from "../logged-in/view";

export function renderView(state: Partial<LoggedInState> = {}) {
  const onInputChange = vi.fn();
  const onSubmit = vi.fn();
  const onPaste = vi.fn();
  const onFilesDrop = vi.fn();
  const onMoreRequested = vi.fn();
  const onReviseSubmit = vi.fn();
  const onReviseCancel = vi.fn();
  const onSamplesRequest = vi.fn();
  const { container } = render(
    <LoggedInView
      itemCount={null}
      lines={[]}
      input=""
      selection={[]}
      processingCount={0}
      isOffline={false}
      {...state}
      onInputChange={onInputChange}
      onSubmit={onSubmit}
      onPaste={onPaste}
      onFilesDrop={onFilesDrop}
      onMoreRequested={onMoreRequested}
      onReviseSubmit={onReviseSubmit}
      onReviseCancel={onReviseCancel}
      onSamplesRequest={onSamplesRequest}
    />,
  );
  return {
    onInputChange,
    onSubmit,
    onPaste,
    onFilesDrop,
    onMoreRequested,
    onReviseSubmit,
    onReviseCancel,
    onSamplesRequest,
    container,
    input: screen.getByRole("textbox", { name: "명령 입력" }) as HTMLInputElement,
  };
}

/** 머리와 글을 CSS 간격으로 띄워 그리므로, 자식 칸을 한 칸 띄어 이어 붙여 화면에 보이는 줄로 만든다. */
export function shownLine(element: Element): string {
  return Array.from(element.children, (child) => child.textContent).join(" ");
}

/** 명령 출력 줄. 터미널 머리(두더지와 그 아래 안내)는 명령의 출력이 아니라 뺀다. */
export function outputLines(container: HTMLElement): Element[] {
  return Array.from(container.querySelectorAll("[role=log] .gt-prompt, [role=log] .gt-line")).filter(
    (line) => line.closest(".gt-head") === null,
  );
}

export function headLines(state: Partial<LoggedInState>): string[] {
  const { container } = renderView(state);
  return Array.from(container.querySelectorAll(".gt-head .gt-line"), shownLine);
}

export function shownOutput(lines: LoggedInState["lines"]): string[] {
  const { container } = renderView({ lines });
  return outputLines(container).map(shownLine);
}

export function item(overrides: Partial<ItemSummary> = {}): ItemSummary {
  return {
    number: 131,
    kind: "link",
    title: "카페 텀블러 할인, 올겨울 캠페인 늘었다",
    source: "팀 가상 기사",
    status: "received",
    blockedReason: null,
    listSummary: null,
    summarySource: null,
    partialNote: null,
    tags: [],
    matchedIn: null,
    savedAt: "2026-11-27T11:00:00+09:00",
    ...overrides,
  };
}

export const KEEP = { kind: "prompt", text: "담기 https://example.com/a" } as const;
