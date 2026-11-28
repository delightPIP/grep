import { act, cleanup, fireEvent, render, screen, within } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { ItemDetail, ItemSummary, TerminalLine } from "../../support/view-state";
import type { ArchiveState, SettingsState } from "../../support/view-state";
import { layoutFor } from "./layout";
import { LoggedInView, type LoggedInViewProps } from "./view";

const DEFAULT_WIDTH = window.innerWidth;

afterEach(() => {
  cleanup();
  setWidth(DEFAULT_WIDTH);
});

function setWidth(width: number) {
  Object.defineProperty(window, "innerWidth", { configurable: true, value: width });
}

function resizeTo(width: number) {
  act(() => {
    setWidth(width);
    window.dispatchEvent(new Event("resize"));
  });
}

function item(number: number, overrides: Partial<ItemSummary> = {}): ItemSummary {
  return {
    number,
    kind: "link",
    title: `자료 ${number}`,
    source: "example.com",
    status: "ready",
    blockedReason: null,
    listSummary: null,
    summarySource: null,
    partialNote: null,
    tags: [],
    matchedIn: null,
    savedAt: "2026-11-26T05:03:00Z",
    ...overrides,
  };
}

function detail(number: number): ItemDetail {
  return {
    item: item(number),
    url: null,
    handoffSummary: null,
    allTags: [],
    bundles: [],
    bodyLength: null,
    body: null,
    bodyFromImage: false,
    originalUrl: null,
    previewUrl: null,
  };
}

const ARCHIVE: ArchiveState = {
  groups: [
    { group: "tag", value: "결제", count: 2 },
    { group: "format", value: "link", count: 5 },
    { group: "source", value: "direct", count: 1 },
    { group: "date", value: "today", count: 3 },
  ],
  bundles: [
    { name: "결제", count: 2 },
    { name: "빈묶음", count: 0 },
  ],
  savedSearches: [
    { query: "토스", count: 4 },
    { query: "없는것", count: 0 },
  ],
  filter: { kind: "all" },
  items: [item(7), item(6)],
  hasMore: true,
  status: "idle",
};

const SETTINGS: SettingsState = {
  account: { authProvider: "github", itemCount: 34 },
  connections: [{ number: 3, client: "Claude", connectedAt: "2026-11-20T01:00:00Z", lastReadAt: null }],
};

function renderView(state: Partial<LoggedInViewProps> = {}) {
  const callbacks = {
    onInputChange: vi.fn(),
    onSubmit: vi.fn(),
    onPaste: vi.fn(),
    onFilesDrop: vi.fn(),
    onArchiveOpen: vi.fn(),
    onArchiveSelect: vi.fn(),
    onArchiveMore: vi.fn(),
    onSettingsOpen: vi.fn(),
    onThemeChange: vi.fn(),
  };
  const props: LoggedInViewProps = {
    itemCount: 34,
    lines: [],
    input: "",
    selection: [],
    processingCount: 0,
    isOffline: false,
    ...callbacks,
    ...state,
  };
  const result = render(<LoggedInView {...props} />);
  const rerender = (next: Partial<LoggedInViewProps>) => result.rerender(<LoggedInView {...props} {...next} />);
  return { ...callbacks, container: result.container, rerender };
}

const nav = () => screen.queryByRole("navigation", { name: "화면 이동" });
const navItem = (name: string) => within(nav()!).getByRole("button", { name: new RegExp(name) });
const current = () => within(nav()!).getByRole("button", { current: "page" }).textContent;

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

describe("보관함 화면(#168, ARC-007·ARC-011)", () => {
  function openArchive(state: Partial<LoggedInViewProps> = {}, width = 800) {
    setWidth(width);
    const view = renderView({ archive: ARCHIVE, ...state });
    fireEvent.click(navItem("보관함"));
    return view;
  }

  it("보관함을_처음_열었을때_상태가_없으면_archiveOpen을_한번만_알리는지", () => {
    // given
    setWidth(800);
    const { onArchiveOpen, rerender } = renderView({ archive: null });

    // when
    fireEvent.click(navItem("보관함"));
    rerender({ archive: ARCHIVE });
    fireEvent.click(navItem("터미널"));
    fireEvent.click(navItem("보관함"));

    // then
    expect(onArchiveOpen).toHaveBeenCalledTimes(1);
  });

  it("구역을_보면_묶음_저장한찾기_형식_출처_날짜_태그_차례이고_0건_저장한_찾기만_숨는지", () => {
    // given
    openArchive();

    // when
    const region = screen.getByRole("region", { name: "보관함" });
    const groups = within(region).getAllByRole("group").map((group) => group.getAttribute("aria-label"));

    // then
    expect(groups).toEqual(["묶음", "저장한 찾기", "형식", "출처", "날짜", "태그 (AI 추정)"]);
    expect(within(region).getByRole("button", { name: "빈묶음 0건" })).toBeTruthy();
    expect(within(region).queryByRole("button", { name: /없는것/ })).toBeNull();
    expect(within(region).getByRole("button", { name: "직접 넣음 1건" })).toBeTruthy();
    expect(within(region).getByRole("button", { name: "#결제 2건" })).toBeTruthy();
    expect(within(region).getByRole("button", { name: "오늘 3건" })).toBeTruthy();
  });

  it("구역을_눌렀을때_알림을_보면_그_필터로_archiveSelect하는지", () => {
    // given
    const { onArchiveSelect } = openArchive();

    // when
    fireEvent.click(screen.getByRole("button", { name: "링크 5건" }));
    fireEvent.click(screen.getByRole("button", { name: "토스 4건" }));

    // then
    expect(onArchiveSelect).toHaveBeenNthCalledWith(1, { kind: "auto", group: "format", value: "link" });
    expect(onArchiveSelect).toHaveBeenNthCalledWith(2, { kind: "savedSearch", query: "토스" });
  });

  it("번호를_눌렀을때_명령을_보면_고르기_N을_바로_실행하고_치던_글을_되돌리는지", () => {
    // given
    const { onSubmit, onInputChange } = openArchive({ input: "찾기 결" });

    // when
    fireEvent.click(screen.getByRole("button", { name: "7" }));

    // then
    expect(onSubmit).toHaveBeenCalledWith("고르기 7");
    expect(onInputChange).toHaveBeenLastCalledWith("찾기 결");
  });

  it("고른_번호를_다시_눌렀을때_명령을_보면_고르기_빼기_N을_바로_실행하는지", () => {
    // given
    const { onSubmit } = openArchive({ selection: [{ number: 7, title: "자료 7", kind: "text" as const, source: null }] });

    // when
    fireEvent.click(screen.getByRole("button", { name: "7" }));

    // then
    expect(onSubmit).toHaveBeenCalledWith("고르기 빼기 7");
  });

  it("넓은_폭에서_자세히_보기_칸을_닫기나_Esc로_닫았을때_화면을_보면_칸이_사라지고_명령은_남지_않는지", () => {
    // given
    const { onSubmit, rerender } = openArchive({}, 1200);
    const opened: Partial<LoggedInViewProps> = {
      archive: ARCHIVE,
      lines: [{ kind: "prompt", text: "열기 7" }, { kind: "itemDetail", detail: detail(7) }],
    };
    fireEvent.click(screen.getByRole("button", { name: "자료 7" }));
    rerender(opened);

    // when
    fireEvent.click(within(screen.getByRole("region", { name: "자세히 보기 칸" })).getByRole("button", { name: "닫기" }));

    // then
    expect(screen.queryByRole("region", { name: "자세히 보기 칸" })).toBeNull();

    // when
    fireEvent.click(screen.getByRole("button", { name: "자료 7" }));
    rerender(opened);
    fireEvent.keyDown(document, { key: "Escape" });

    // then
    expect(screen.queryByRole("region", { name: "자세히 보기 칸" })).toBeNull();
    expect(onSubmit.mock.calls.map(([command]) => command)).toEqual(["열기 7", "열기 7"]);
  });

  it("넓은_폭에서_제목을_눌렀을때_화면을_보면_열기_N을_실행하고_오른쪽_칸에_자세히_보기를_여는지", () => {
    // given
    const { onSubmit, rerender } = openArchive({}, 1200);

    // when
    fireEvent.click(screen.getByRole("button", { name: "자료 7" }));
    rerender({ archive: ARCHIVE, lines: [{ kind: "prompt", text: "열기 7" }, { kind: "itemDetail", detail: detail(7) }] });

    // then
    expect(onSubmit).toHaveBeenCalledWith("열기 7");
    const pane = screen.getByRole("region", { name: "자세히 보기 칸" });
    expect(within(pane).getByRole("region", { name: "자세히 보기" })).toBeTruthy();
    expect(screen.getByRole("region", { name: "보관함" })).toBeTruthy();
  });

  it("좁은_폭에서_제목을_눌렀을때_화면을_보면_목록_대신_자세히_보기를_열고_보관함으로_돌아가는지", () => {
    // given
    const lines: TerminalLine[] = [{ kind: "itemDetail", detail: detail(7) }];
    openArchive({ lines }, 800);

    // when
    fireEvent.click(screen.getByRole("button", { name: "자료 7" }));

    // then
    expect(screen.queryByRole("region", { name: "보관함" })).toBeNull();
    expect(screen.getByRole("region", { name: "자세히 보기" })).toBeTruthy();
    fireEvent.click(screen.getByRole("button", { name: "‹ 보관함" }));
    expect(screen.getByRole("region", { name: "보관함" })).toBeTruthy();
  });

  it("자세히_보기의_동작을_눌렀을때_화면을_보면_터미널로_옮겨_입력줄에_찍는지", () => {
    // given
    const lines: TerminalLine[] = [{ kind: "itemDetail", detail: detail(7) }];
    const { onInputChange, onSubmit } = openArchive({ lines }, 1200);
    fireEvent.click(screen.getByRole("button", { name: "자료 7" }));
    onSubmit.mockClear();

    // when
    fireEvent.click(within(screen.getByRole("region", { name: "자세히 보기 칸" })).getByRole("button", { name: "버리기 7" }));

    // then
    expect(onInputChange).toHaveBeenLastCalledWith("버리기 7");
    expect(onSubmit).not.toHaveBeenCalled();
    expect(current()).toContain("터미널");
  });

  it("더_보기를_눌렀을때_알림을_보면_archiveMore인지", () => {
    // given
    const { onArchiveMore } = openArchive();

    // when
    fireEvent.click(screen.getByRole("button", { name: "더 보기" }));

    // then
    expect(onArchiveMore).toHaveBeenCalledTimes(1);
  });

  it("불러오는_중이거나_실패했을때_목록을_보면_상태를_알리고_다시_시도하면_다음_쪽을_받는지", () => {
    // given
    const { rerender, onArchiveMore } = openArchive({ archive: { ...ARCHIVE, status: "loading" } });
    expect(screen.getByText("· 불러오는 중")).toBeTruthy();
    expect(screen.queryByRole("button", { name: "더 보기" })).toBeNull();

    // when
    rerender({ archive: { ...ARCHIVE, status: "error" } });
    fireEvent.click(screen.getByRole("button", { name: "다시 시도" }));

    // then
    expect(screen.getByText(/불러오기 안 됨/)).toBeTruthy();
    expect(screen.getAllByRole("button", { name: /^자료 \d$/ })).toHaveLength(2);
    expect(onArchiveMore).toHaveBeenCalledTimes(1);
  });
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
