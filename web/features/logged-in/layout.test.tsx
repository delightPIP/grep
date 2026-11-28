import { cleanup, fireEvent, screen, within } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { DEFAULT_WIDTH, setWidth, resizeTo, ARCHIVE, renderView, nav, navItem, current } from "./screens-test-support";
import { layoutFor } from "./layout";
import type { LoggedInViewProps } from "./view";

afterEach(() => {
  cleanup();
  setWidth(DEFAULT_WIDTH);
});

describe("폭별 배치(COM-011)", () => {
  it.each([
    [599, "tabs"],
    [600, "rail"],
    [1007, "rail"],
    [1008, "sidebar"],
  ] as const)("폭이_%ipx일때_배치를_고르면_%s인지", (width, expected) => {
    // given
    setWidth(width);

    // when
    const { container } = renderView();

    // then
    expect(layoutFor(width)).toBe(expected);
    expect(container.querySelector("main")!.className).toContain(`gt-shell-${expected}`);
  });

  it("웹을_열었을때_이동_항목을_보면_터미널_보관함_설정_차례이고_터미널에서_시작하는지", () => {
    // given
    setWidth(1200);

    // when
    renderView();

    // then
    const labels = within(nav()!).getAllByRole("button").map((button) => button.querySelector(".gt-nav-label")!.textContent);
    expect(labels).toEqual(["터미널", "보관함", "설정"]);
    expect(current()).toContain("터미널");
    expect(screen.getByRole("textbox", { name: "명령 입력" })).toBeTruthy();
  });

  it("보관함을_보다가_폭이_바뀌었을때_화면을_보면_보던_화면과_치던_글과_선택이_남는지", () => {
    // given
    setWidth(1200);
    const { container } = renderView({ archive: ARCHIVE, input: "찾기 결", selection: [{ number: 7, title: "자료 7", kind: "text" as const, source: null }] });
    fireEvent.click(navItem("보관함"));

    // when
    resizeTo(800);
    resizeTo(500);

    // then
    expect(current()).toContain("보관함");
    expect(screen.getByRole("region", { name: "보관함" })).toBeTruthy();
    fireEvent.click(navItem("터미널"));
    resizeTo(1100);
    expect((screen.getByRole("textbox", { name: "명령 입력" }) as HTMLInputElement).value).toBe("찾기 결");
    expect(container.querySelector(".gt-selection")).not.toBeNull();
  });

  it("터치_기기의_좁은_폭에서_입력줄에_초점이_있을때_하단_탭을_보면_숨고_떠나면_다시_보이는지", () => {
    // given
    setWidth(400);
    vi.stubGlobal("matchMedia", (query: string) => ({ matches: query === "(pointer: coarse)" }));
    renderView();
    const input = screen.getByRole("textbox", { name: "명령 입력" });

    // when
    fireEvent.focus(input);
    const whileTyping = nav();
    fireEvent.blur(input);

    // then
    expect(whileTyping).toBeNull();
    expect(nav()).not.toBeNull();
    vi.unstubAllGlobals();
  });

  it("마우스_기기의_좁은_창에서_입력줄에_초점이_있을때_하단_탭을_보면_그대로인지", () => {
    // given
    setWidth(400);
    renderView();

    // when
    fireEvent.focus(screen.getByRole("textbox", { name: "명령 입력" }));

    // then
    expect(nav()).not.toBeNull();
  });

  it.each<[string, Partial<LoggedInViewProps>]>([
    ["고르기 중", { selection: [{ number: 7, title: "자료 7", kind: "text" as const, source: null }] }],
    ["확인 줄", { lines: [{ kind: "dropConfirm", total: 3 }] }],
    ["고치기 칸", { revising: { number: 7, title: "자료 7", summary: "" } }],
  ])("좁은_폭에서_%s일때_하단_탭을_보면_숨는지", (_name, state) => {
    // given
    setWidth(400);

    // when
    renderView(state);

    // then
    expect(nav()).toBeNull();
  });

  it("넓은_폭일때_사이드바를_보면_배지_없이_보관함_구역이_있는지", () => {
    // given
    setWidth(1200);

    // when
    renderView({ archive: ARCHIVE, processingCount: 2 });

    // then
    expect(within(nav()!).getByRole("group", { name: "묶음" })).toBeTruthy();
    expect(navItem("터미널").textContent).toBe(">_터미널");
  });
});
