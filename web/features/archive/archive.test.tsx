import { cleanup, fireEvent, screen, within } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import type { TerminalLine } from "../../support/view-state";
import { DEFAULT_WIDTH, setWidth, detail, ARCHIVE, renderView, navItem, current } from "../logged-in/screens-test-support";
import type { LoggedInViewProps } from "../logged-in/view";

afterEach(() => {
  cleanup();
  setWidth(DEFAULT_WIDTH);
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
