import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { LoggedInState } from "../../support/view-state";
import { LoggedInView } from "./view";

afterEach(cleanup);

function renderView(state: Partial<LoggedInState> = {}) {
  const onInputChange = vi.fn();
  const onSubmit = vi.fn();
  const { container } = render(
    <LoggedInView
      itemCount={null}
      lines={[]}
      input=""
      {...state}
      onInputChange={onInputChange}
      onSubmit={onSubmit}
    />,
  );
  return {
    onInputChange,
    onSubmit,
    container,
    input: screen.getByRole("textbox") as HTMLInputElement,
  };
}

/** 머리와 글을 CSS 간격으로 띄워 그리므로, 자식 칸을 한 칸 띄어 이어 붙여 화면에 보이는 줄로 만든다. */
function shownLine(element: Element): string {
  return Array.from(element.children, (child) => child.textContent).join(" ");
}

function outputLines(container: HTMLElement): Element[] {
  return Array.from(container.querySelectorAll("[role=log] .gt-prompt, [role=log] .gt-line"));
}

describe("LoggedInView", () => {
  it("자료수를_받았을때_화면을그리면_상태줄에_자료N과_도움말키를_보여주는지", () => {
    // given
    // when
    const { container } = renderView({ itemCount: 34 });

    // then
    const status = container.querySelector(".gt-status")!;
    expect(status.querySelector("b")?.textContent).toBe("34");
    expect(status.textContent).toContain("자료 34");
    expect(status.textContent).toContain("? 도움말");
  });

  it("자료수를_아직모를때_화면을그리면_상태줄에_숫자없이_자료만_보여주는지", () => {
    // given
    // when
    const { container } = renderView({ itemCount: null });

    // then
    const status = container.querySelector(".gt-status")!;
    expect(status.textContent).toContain("자료");
    expect(status.querySelector("b")).toBeNull();
  });

  it("출력줄이_있을때_화면을그리면_입력줄과_없는명령을_정책문구로_보여주는지", () => {
    // given
    const lines: LoggedInState["lines"] = [
      { kind: "prompt", text: "ㅁㄴㅇ" },
      { kind: "unknownCommand", name: "ㅁㄴㅇ" },
    ];

    // when
    const { container } = renderView({ lines });

    // then
    expect(outputLines(container).map(shownLine)).toEqual(["그렙 ~ $ ㅁㄴㅇ", "✗ 없는 명령: ㅁㄴㅇ"]);
  });

  it("없는명령으로_끝난입력줄을_그리면_프롬프트를_실패색으로_그리는지", () => {
    // given
    const lines: LoggedInState["lines"] = [
      { kind: "prompt", text: "최근" },
      { kind: "prompt", text: "찻기 결제" },
      { kind: "unknownCommand", name: "찻기" },
    ];

    // when
    const { container } = renderView({ lines });

    // then
    const prompts = Array.from(container.querySelectorAll(".gt-prompt"));
    expect(prompts.map((p) => p.classList.contains("gt-prompt-fail"))).toEqual([false, true]);
  });

  it("출력줄이_비었을때_화면을그리면_창제목이_처음이고_출력이_없는지", () => {
    // given
    // when
    const { container } = renderView({ lines: [] });

    // then
    expect(container.querySelector(".gt-titlebar-name")?.textContent).toBe("그렙 — 처음");
    expect(outputLines(container)).toHaveLength(0);
  });

  it("명령을_친뒤에_화면을그리면_창제목이_마지막명령_이름인지", () => {
    // given
    const lines: LoggedInState["lines"] = [{ kind: "prompt", text: "최근 3주전" }];

    // when
    const { container } = renderView({ lines });

    // then
    expect(container.querySelector(".gt-titlebar-name")?.textContent).toBe("그렙 — 최근");
  });

  it("입력줄이_비었을때_화면을그리면_시안의_안내글을_보여주는지", () => {
    // given
    // when
    const { input } = renderView();

    // then
    expect(input.placeholder).toBe("링크 붙여 넣기 또는 명령");
  });

  it("되살린입력이_있을때_화면을그리면_입력줄에_그대로_보여주는지", () => {
    // given
    // when
    const { input } = renderView({ input: "최근" });

    // then
    expect(input.value).toBe("최근");
  });

  it("입력줄에_글을치면_바뀐글을_알리는지", () => {
    // given
    const { input, onInputChange } = renderView();

    // when
    fireEvent.change(input, { target: { value: "도움말" } });

    // then
    expect(onInputChange).toHaveBeenCalledExactlyOnceWith("도움말");
  });

  it("입력줄에서_엔터를누르면_입력한글로_제출하는지", () => {
    // given
    const { input, onSubmit } = renderView({ input: "도움말" });

    // when
    fireEvent.keyDown(input, { key: "Enter" });

    // then
    expect(onSubmit).toHaveBeenCalledExactlyOnceWith("도움말");
  });

  it("한글을_조합하는중일때_엔터를누르면_제출하지않는지", () => {
    // given
    const { input, onSubmit } = renderView({ input: "도움" });

    // when
    fireEvent.keyDown(input, { key: "Enter", isComposing: true });

    // then
    expect(onSubmit).not.toHaveBeenCalled();
  });
});
