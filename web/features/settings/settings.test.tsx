import { cleanup, fireEvent, screen, within } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { DEFAULT_WIDTH, setWidth, SETTINGS, renderView, navItem, current } from "../logged-in/screens-test-support";
import type { LoggedInViewProps } from "../logged-in/view";

afterEach(() => {
  cleanup();
  setWidth(DEFAULT_WIDTH);
});

describe("설정 화면(#168, 시안 26)", () => {
  function openSettings(state: Partial<LoggedInViewProps> = {}) {
    setWidth(1200);
    const view = renderView({ settings: SETTINGS, ...state });
    fireEvent.click(navItem("설정"));
    return view;
  }

  it("설정을_열었을때_화면을_보면_settingsOpen을_알리고_계정_연결_휴지통_화면_로그아웃_차례인지", () => {
    // given
    // when
    const { onSettingsOpen } = openSettings();

    // then
    expect(onSettingsOpen).toHaveBeenCalledTimes(1);
    const groups = within(screen.getByRole("region", { name: "설정" }))
      .getAllByRole("region")
      .map((group) => group.getAttribute("aria-label"));
    expect(groups).toEqual(["계정", "AI 도구 연결", "휴지통", "화면", "로그아웃"]);
    expect(screen.getByText("GitHub 계정")).toBeTruthy();
    expect(screen.getByText("연결 11/20")).toBeTruthy();
  });

  it.each([
    ["끊기", "연결 끊기 3"],
    ["열기", "휴지통"],
    ["로그아웃", "로그아웃"],
    ["모든 기기", "로그아웃 모든기기"],
  ])("%s을_눌렀을때_화면을_보면_터미널로_옮겨_%s를_실행하는지", (button, command) => {
    // given
    const { onSubmit } = openSettings();

    // when
    fireEvent.click(screen.getByRole("button", { name: button }));

    // then
    expect(onSubmit).toHaveBeenCalledWith(command);
    expect(current()).toContain("터미널");
  });
});

describe("테마 줄(#169, COM-012)", () => {
  function openTheme(state: Partial<LoggedInViewProps> = {}) {
    setWidth(1200);
    const view = renderView(state);
    fireEvent.click(navItem("설정"));
    return view;
  }

  it("고른_테마가_없을때_테마_줄을_보면_세_가지_차례이고_시스템_따름이_골라져_있는지", () => {
    // given
    // when
    openTheme();

    // then
    const group = screen.getByRole("radiogroup", { name: "테마" });
    const options = within(group).getAllByRole("radio");
    expect(options.map((option) => option.textContent)).toEqual(["시스템 따름", "밝게", "어둡게"]);
    expect(within(group).getByRole("radio", { checked: true }).textContent).toBe("시스템 따름");
  });

  it("어둡게를_눌렀을때_알림을_보면_dark를_넘기고_고른_값이_표시되는지", () => {
    // given
    const { onThemeChange, rerender } = openTheme({ theme: "light" });
    expect(screen.getByRole("radio", { checked: true }).textContent).toBe("밝게");

    // when
    fireEvent.click(screen.getByRole("radio", { name: "어둡게" }));
    rerender({ theme: "dark" });

    // then
    expect(onThemeChange).toHaveBeenCalledWith("dark");
    expect(screen.getByRole("radio", { checked: true }).textContent).toBe("어둡게");
  });
});
