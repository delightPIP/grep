import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { applyStoredTheme, applyTheme, readTheme, saveTheme, THEME_KEY } from "./theme-store";

beforeEach(() => {
  localStorage.clear();
  document.documentElement.removeAttribute("data-theme");
});
afterEach(() => vi.restoreAllMocks());

describe("테마 저장소(COM-012)", () => {
  it("남긴값이없을때_읽으면_시스템따름인지", () => {
    // given: 빈 저장소

    // when
    const theme = readTheme();

    // then
    expect(theme).toBe("system");
  });

  it.each(["light", "dark", "system"] as const)("테마를%s로남겼을때_다시읽으면_같은값인지", (choice) => {
    // given
    saveTheme(choice);

    // when
    const theme = readTheme();

    // then
    expect(theme).toBe(choice);
    expect(localStorage.getItem(THEME_KEY)).toBe(choice);
  });

  it("모르는값이남아있을때_읽으면_시스템따름인지", () => {
    // given
    localStorage.setItem(THEME_KEY, "sepia");

    // when
    const theme = readTheme();

    // then
    expect(theme).toBe("system");
  });

  it("저장소가막혔을때_읽고쓰면_던지지않고시스템따름인지", () => {
    // given
    vi.spyOn(Storage.prototype, "getItem").mockImplementation(() => {
      throw new Error("blocked");
    });
    vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => {
      throw new Error("blocked");
    });

    // when
    const write = () => saveTheme("dark");
    const theme = readTheme();

    // then: 오류를 알리지 않는다(규칙 5)
    expect(write).not.toThrow();
    expect(theme).toBe("system");
  });

  it.each(["light", "dark"] as const)("테마를%s로고르면_html에data-theme를붙이는지", (choice) => {
    // given, when
    applyTheme(choice);

    // then
    expect(document.documentElement.dataset.theme).toBe(choice);
  });

  it("어둡게였다가시스템따름을고르면_data-theme를지우는지", () => {
    // given
    applyTheme("dark");

    // when
    applyTheme("system");

    // then
    expect(document.documentElement.hasAttribute("data-theme")).toBe(false);
  });

  it("남긴값이있을때_시작하며적용하면_그테마를붙이는지", () => {
    // given
    localStorage.setItem(THEME_KEY, "light");

    // when
    const theme = applyStoredTheme();

    // then
    expect(theme).toBe("light");
    expect(document.documentElement.dataset.theme).toBe("light");
  });
});
