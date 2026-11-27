import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { ItemSummary, LoggedInState } from "../../support/view-state";
import { LoggedInView } from "./view";

afterEach(cleanup);

function renderView(state: Partial<LoggedInState> = {}) {
  const onInputChange = vi.fn();
  const onSubmit = vi.fn();
  const onPaste = vi.fn();
  const onFilesDrop = vi.fn();
  const onMoreRequested = vi.fn();
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
    />,
  );
  return {
    onInputChange,
    onSubmit,
    onPaste,
    onFilesDrop,
    onMoreRequested,
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

function shownOutput(lines: LoggedInState["lines"]): string[] {
  const { container } = renderView({ lines });
  return outputLines(container).map(shownLine);
}

function item(overrides: Partial<ItemSummary> = {}): ItemSummary {
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

const KEEP = { kind: "prompt", text: "담기 https://example.com/a" } as const;

describe("LoggedInView", () => {
  it("자료수를받았을때_화면을그리면_상태줄에자료N과도움말키를보여주는지", () => {
    // given
    // when
    const { container } = renderView({ itemCount: 34 });

    // then
    const status = container.querySelector(".gt-status")!;
    expect(status.querySelector("b")?.textContent).toBe("34");
    expect(status.textContent).toContain("자료 34");
    expect(status.textContent).toContain("? 도움말");
  });

  it("자료수를아직모를때_화면을그리면_상태줄에숫자없이자료만보여주는지", () => {
    // given
    // when
    const { container } = renderView({ itemCount: null });

    // then
    const status = container.querySelector(".gt-status")!;
    expect(status.textContent).toContain("자료");
    expect(status.querySelector("b")).toBeNull();
  });

  it("출력줄이있을때_화면을그리면_입력줄과없는명령을정책문구로보여주는지", () => {
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

  it("없는명령으로끝난입력줄이있을때_화면을그리면_프롬프트를실패색으로그리는지", () => {
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

  it("출력줄이비었을때_화면을그리면_창제목이처음이고출력이없는지", () => {
    // given
    // when
    const { container } = renderView({ lines: [] });

    // then
    expect(container.querySelector(".gt-titlebar-name")?.textContent).toBe("그렙 — 처음");
    expect(outputLines(container)).toHaveLength(0);
  });

  it("명령을친뒤일때_화면을그리면_창제목이마지막명령이름인지", () => {
    // given
    const lines: LoggedInState["lines"] = [{ kind: "prompt", text: "최근 3주전" }];

    // when
    const { container } = renderView({ lines });

    // then
    expect(container.querySelector(".gt-titlebar-name")?.textContent).toBe("그렙 — 최근");
  });

  it("입력줄이비었을때_화면을그리면_시안의안내글을보여주는지", () => {
    // given
    // when
    const { input } = renderView();

    // then
    expect(input.placeholder).toBe("링크 붙여 넣기 또는 명령");
  });

  it("되살린입력이있을때_화면을그리면_입력줄에그대로보여주는지", () => {
    // given
    // when
    const { input } = renderView({ input: "최근" });

    // then
    expect(input.value).toBe("최근");
  });

  it("터미널이떠있을때_입력줄에글을치면_바뀐글을알리는지", () => {
    // given
    const { input, onInputChange } = renderView();

    // when
    fireEvent.change(input, { target: { value: "도움말" } });

    // then
    expect(onInputChange).toHaveBeenCalledExactlyOnceWith("도움말");
  });

  it("터미널이떠있을때_입력줄에서엔터를누르면_입력한글로제출하는지", () => {
    // given
    const { input, onSubmit } = renderView({ input: "도움말" });

    // when
    fireEvent.keyDown(input, { key: "Enter" });

    // then
    expect(onSubmit).toHaveBeenCalledExactlyOnceWith("도움말");
  });

  it("한글을조합하는중일때_엔터를누르면_제출하지않는지", () => {
    // given
    const { input, onSubmit } = renderView({ input: "도움" });

    // when
    fireEvent.keyDown(input, { key: "Enter", isComposing: true });

    // then
    expect(onSubmit).not.toHaveBeenCalled();
  });

  it("아직그리는법이없는줄이있을때_화면을그리면_없는명령으로그리지않고친줄은그리는지", () => {
    // given
    const lines: LoggedInState["lines"] = [
      { kind: "prompt", text: "도움말" },
      { kind: "guide" },
    ];

    // when
    const { container } = renderView({ lines });

    // then
    expect(container.textContent).toContain("도움말");
    expect(container.textContent).not.toContain("없는 명령");
  });

  describe("저장 줄(#57, ARC-005·COM-001·COM-004)", () => {
    it("링크를저장했을때_화면을그리면_제목과출처뒤에요약생성중을보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [KEEP, { kind: "saved", item: item() }];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown.slice(1)).toEqual([
        "✓ 저장됨  카페 텀블러 할인, 올겨울 캠페인 늘었다 (팀 가상 기사)",
        "· 요약 생성 중",
      ]);
    });

    it("글을저장했을때_화면을그리면_글표시와첫줄24자까지만보이는지", () => {
      // given
      const title = "텀블러 세척 메모 베이킹소다 한 숟갈 넣고 하룻밤 두기\n둘째 줄";
      const lines: LoggedInState["lines"] = [KEEP, { kind: "saved", item: item({ kind: "text", title, source: null }) }];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown[1]).toBe("✓ 저장됨 (글)  텀블러 세척 메모 베이킹소다 한 숟갈 넣고");
    });

    it("요약이끝난자료를저장했을때_화면을그리면_요약생성중을보이지않는지", () => {
      // given
      const lines: LoggedInState["lines"] = [KEEP, { kind: "saved", item: item({ status: "ready" }) }];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown).not.toContain("· 요약 생성 중");
    });

    it("이미저장된링크일때_화면을그리면_기존번호와그자료목록행과고르기안내를보이는지", () => {
      // given
      const saved = item({ status: "ready", listSummary: "카페 3곳이 텀블러 할인을 늘렸다", tags: ["텀블러"] });
      const lines: LoggedInState["lines"] = [KEEP, { kind: "alreadySaved", item: saved }];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown.slice(1)).toEqual([
        "! 이미 저장됨 → 131번 (새로 만들지 않음)",
        "131 카페 텀블러 할인, 올겨울 캠페인 늘었다 팀 가상 기사 2026-11-27 11:00",
        "카페 3곳이 텀블러 할인을 늘렸다 #텀블러",
        "→ 고르기 131",
      ]);
    });

    it("휴지통자료와같을때_화면을그리면_되살리기안내를보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [KEEP, { kind: "inTrash", number: 57 }];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown[1]).toBe("! 휴지통에 있음 → 57번. 되살리기 57");
    });

    it.each([
      [{ kind: "disconnected" }, "연결 끊김"],
      [{ kind: "timedOut" }, "응답 없음"],
      [{ kind: "serverError" }, "서버 오류"],
    ] as const)("입력줄에되돌린저장이실패했을때_이유가%o이면_이유와입력은남겨둠을보이는지", (reason, word) => {
      // given
      const lines: LoggedInState["lines"] = [KEEP, { kind: "saveFailed", reason, recovery: { kind: "inputKept" } }];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown[1]).toBe(`✗ 저장 안 됨: ${word}  입력은 남겨 둠`);
    });

    it("새글을친뒤저장이실패했을때_화면을그리면_다시칠명령을다음줄에보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        KEEP,
        {
          kind: "saveFailed",
          reason: { kind: "timedOut" },
          recovery: { kind: "retry", command: "담기 https://example.com/a" },
        },
      ];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown.slice(1)).toEqual(["✗ 저장 안 됨: 응답 없음", "→ 다시: 담기 https://example.com/a"]);
    });

    it("놓은파일이연결끊김으로실패했을때_화면을그리면_파일이름을붙이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        { kind: "prompt", text: "담기 예산안.pdf" },
        { kind: "saveFailed", reason: { kind: "disconnected" }, recovery: { kind: "file", name: "예산안.pdf" } },
      ];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown[1]).toBe("✗ 저장 안 됨: 연결 끊김 (예산안.pdf)");
    });

    it("놓은파일이20MB를넘었을때_화면을그리면_COM004문구로이름과크기를보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        { kind: "prompt", text: "담기 영상.mov" },
        {
          kind: "saveFailed",
          reason: { kind: "tooLarge", fileName: "영상.mov", bytes: 31_457_280 },
          recovery: { kind: "file", name: "영상.mov" },
        },
      ];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown[1]).toBe("✗ 저장 안 됨: 20MB 넘음 (영상.mov · 30MB)");
    });

    it("놓은파일이받지않는형식일때_화면을그리면_COM004문구로확장자를보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        { kind: "prompt", text: "담기 자료.zip" },
        {
          kind: "saveFailed",
          reason: { kind: "unsupportedFormat", fileExtension: "zip" },
          recovery: { kind: "file", name: "자료.zip" },
        },
      ];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown[1]).toBe("✗ 저장 안 됨: 받지 않는 형식 (.zip)");
    });

    it("담기만쳤을때_화면을그리면_저장할것없음과예시를보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        { kind: "prompt", text: "담기" },
        { kind: "missingArgument", command: "keep" },
      ];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown[1]).toBe("✗ 저장할 것 없음  예: 담기 https://…");
    });
  });

  describe("붙여 넣기·끌어다 놓기(#57)", () => {
    function clipboard(text: string) {
      return { clipboardData: { getData: () => text, files: [] } };
    }

    function filesDrag(files: File[] = []) {
      return { dataTransfer: { types: ["Files"], files } };
    }

    it("입력줄이비었을때_링크를붙여넣으면_붙인글을알리고입력줄에넣지않는지", () => {
      // given
      const { input, onPaste } = renderView();

      // when
      const notPrevented = fireEvent.paste(input, clipboard("https://example.com/a"));

      // then
      expect(onPaste).toHaveBeenCalledExactlyOnceWith("https://example.com/a");
      expect(notPrevented).toBe(false);
    });

    it("입력줄에명령을치던중일때_글을붙여넣으면_저장하지않고입력줄에두는지", () => {
      // given
      const { input, onPaste } = renderView({ input: "찾기 " });

      // when
      const notPrevented = fireEvent.paste(input, clipboard("텀블러"));

      // then
      expect(onPaste).not.toHaveBeenCalled();
      expect(notPrevented).toBe(true);
    });

    it("파일을끌어올때_화면을그리면_놓으면저장과받는형식을보이는지", () => {
      // given
      const { container } = renderView();

      // when
      fireEvent.dragEnter(container.querySelector(".gt-screen")!, filesDrag());

      // then
      expect(screen.getByText("놓으면 저장")).toBeTruthy();
      expect(screen.getByText("링크 · 글 · 이미지 · PDF · md · docx")).toBeTruthy();
    });

    it("파일을끌어온뒤_놓으면_파일들을알리고안내를닫는지", () => {
      // given
      const { container, onFilesDrop } = renderView();
      const screenElement = container.querySelector(".gt-screen")!;
      const pdf = new File(["%PDF"], "예산안.pdf", { type: "application/pdf" });
      fireEvent.dragEnter(screenElement, filesDrag());

      // when
      const notPrevented = fireEvent.drop(screenElement, filesDrag([pdf]));

      // then
      expect(onFilesDrop).toHaveBeenCalledExactlyOnceWith([pdf]);
      expect(notPrevented).toBe(false);
      expect(screen.queryByText("놓으면 저장")).toBeNull();
    });

    it("파일을끌어오다가_화면밖으로나가면_안내를닫는지", () => {
      // given
      const { container } = renderView();
      const screenElement = container.querySelector(".gt-screen")!;
      fireEvent.dragEnter(screenElement, filesDrag());

      // when
      fireEvent.dragLeave(screenElement, { relatedTarget: null });

      // then
      expect(screen.queryByText("놓으면 저장")).toBeNull();
    });
  });

  describe("최근 목록(#60, commands 6절·ARC-002·ARC-004·ARC-005)", () => {
    const RECENT = { kind: "prompt", text: "최근" } as const;

    function recent(items: ItemSummary[], hasMore = false): LoggedInState["lines"] {
      return [RECENT, { kind: "recentList", items, hasMore }];
    }

    it("요약이끝난자료가있을때_최근목록을그리면_번호제목출처저장시각과흐린요약태그를두줄로보이는지", () => {
      // given
      const ready = item({ status: "ready", listSummary: "카페 3곳이 텀블러 할인을 늘렸다", tags: ["텀블러", "캠페인"] });

      // when
      const shown = shownOutput(recent([ready]));

      // then
      expect(shown.slice(1)).toEqual([
        "131 카페 텀블러 할인, 올겨울 캠페인 늘었다 팀 가상 기사 2026-11-27 11:00",
        "카페 3곳이 텀블러 할인을 늘렸다 #텀블러 #캠페인",
      ]);
    });

    it("태그가5개일때_최근목록을그리면_앞3개만보이는지", () => {
      // given
      const ready = item({ status: "ready", listSummary: "요약", tags: ["가", "나", "다", "라", "마"] });

      // when
      const shown = shownOutput(recent([ready]));

      // then
      expect(shown[2]).toBe("요약 #가 #나 #다");
    });

    it("저장시각이UTC로올때_최근목록을그리면_한국시간으로보이는지", () => {
      // given
      const late = item({ savedAt: "2026-11-26T15:30:00Z", source: null });

      // when
      const shown = shownOutput(recent([late]));

      // then
      expect(shown[1]).toBe("131 카페 텀블러 할인, 올겨울 캠페인 늘었다 2026-11-27 00:30");
    });

    it("처리중인자료가있을때_최근목록을그리면_요약자리에흐린요약생성중을보이는지", () => {
      // given
      const items = [item({ number: 132, status: "received" }), item({ status: "processing" })];

      // when
      const { container } = renderView({ lines: recent(items) });

      // then
      const subs = Array.from(container.querySelectorAll(".gt-row-sub"));
      expect(subs.map((sub) => sub.textContent)).toEqual(["· 요약 생성 중", "· 요약 생성 중"]);
      expect(subs.every((sub) => sub.classList.contains("gt-hint"))).toBe(true);
    });

    it("본문을못가져온자료가있을때_최근목록을그리면_알림과고치기번호를보이는지", () => {
      // given
      const blocked = item({ number: 64, status: "blocked", blockedReason: "loginRequired" });

      // when
      const shown = shownOutput(recent([blocked]));

      // then
      expect(shown[2]).toBe("! 본문 못 가져옴 → 고치기 64");
    });

    it("처리가실패한자료가있을때_최근목록을그리면_요약못만듦알림을보이는지", () => {
      // given
      const failed = item({ status: "failed" });

      // when
      const shown = shownOutput(recent([failed]));

      // then
      expect(shown[2]).toBe("! 요약 못 만듦  제목·출처만 넘김");
    });

    it("일부만읽은자료일때_최근목록을그리면_요약끝에일부만읽음을붙이는지", () => {
      // given
      const partial = item({ status: "ready", listSummary: "겨울 굿즈 예산", partialNote: "앞 20쪽만 읽음" });

      // when
      const shown = shownOutput(recent([partial]));

      // then
      expect(shown[2]).toBe("겨울 굿즈 예산 (앞 20쪽만 읽음)");
    });

    it("다음자료가더있을때_더보기를누르면_더보기를알리는지", () => {
      // given
      const { onMoreRequested } = renderView({ lines: recent([item()], true) });

      // when
      fireEvent.click(screen.getByRole("button", { name: "더 보기" }));

      // then
      expect(onMoreRequested).toHaveBeenCalledOnce();
    });

    it("다음자료가없을때_최근목록을그리면_더보기를보이지않는지", () => {
      // given
      // when
      renderView({ lines: recent([item()], false) });

      // then
      expect(screen.queryByRole("button", { name: "더 보기" })).toBeNull();
    });
  });

  describe("찾기 결과(#61, commands 6절·ARC-002)", () => {
    const SEEK = { kind: "prompt", text: "찾기 결제" } as const;
    const QUERY = { text: "결제", words: "결제", tags: [] };
    const ready = (number: number) => item({ number, status: "ready", listSummary: `요약 ${number}`, source: null });

    function found(total: number, items: ItemSummary[], hasMore = false): LoggedInState["lines"] {
      return [SEEK, { kind: "searchResult", query: QUERY, total, items, hasMore }];
    }

    function noResults(text: string, recent: ItemSummary[]): LoggedInState["lines"] {
      return [{ kind: "prompt", text: `찾기 ${text}` }, { kind: "noResults", query: { text, words: "", tags: [] }, recent }];
    }

    it("찾은자료가모두보일때_찾기결과를그리면_머리줄에전체건수와두줄행을보이는지", () => {
      // given
      const lines = found(1, [ready(131)]);

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown.slice(1)).toEqual(["1건", "131 카페 텀블러 할인, 올겨울 캠페인 늘었다 2026-11-27 11:00", "요약 131"]);
    });

    it("찾은자료가10건을넘을때_찾기결과를그리면_머리줄에전체중보인건수와더보기를보이는지", () => {
      // given
      const items = Array.from({ length: 10 }, (_, index) => ready(140 - index));

      // when
      const shown = shownOutput(found(23, items, true));

      // then
      expect(shown[1]).toBe("23건 중 10건");
      expect(shown[shown.length - 1]).toBe("→ 더 보기");
    });

    it("더보기로다음쪽을이어받았을때_찾기결과를그리면_머리숫자가행수와맞는지", () => {
      // given
      const items = Array.from({ length: 20 }, (_, index) => ready(150 - index));

      // when
      const shown = shownOutput(found(23, items, true));

      // then
      expect(shown[1]).toBe("23건 중 20건");
    });

    it("다음쪽이있을때_찾기결과의더보기를누르면_더보기를알리는지", () => {
      // given
      const { onMoreRequested } = renderView({ lines: found(23, [ready(131)], true) });

      // when
      fireEvent.click(screen.getByRole("button", { name: "더 보기" }));

      // then
      expect(onMoreRequested).toHaveBeenCalledOnce();
    });

    it("이미지속글자에서찾았을때_찾기결과를그리면_요약줄끝에흐린이미지속글자를보이는지", () => {
      // given
      const capture = item({ number: 28, status: "ready", listSummary: "파란컵 반값 캠페인 캡처", matchedIn: "imageText", tags: ["텀블러"] });

      // when
      const { container } = renderView({ lines: found(1, [capture]) });

      // then
      const sub = container.querySelector(".gt-row-sub")!;
      expect(shownLine(sub)).toBe("파란컵 반값 캠페인 캡처 · 이미지 속 글자 #텀블러");
      expect(sub.querySelector(".gt-row-match")!.textContent).toBe("· 이미지 속 글자");
    });

    it("화면에보이는곳에서찾았을때_찾기결과를그리면_일치위치를붙이지않는지", () => {
      // given
      const byTitle = item({ status: "ready", listSummary: "요약", matchedIn: "title" });

      // when
      const { container } = renderView({ lines: found(1, [byTitle]) });

      // then
      expect(container.querySelector(".gt-row-match")).toBeNull();
    });

    it("찾은자료가없을때_찾기결과를그리면_0건과검색결과아님머리줄뒤에최근자료를보이는지", () => {
      // given
      const recent = [ready(133), ready(132), ready(131)];

      // when
      const shown = shownOutput(noResults("결제", recent));

      // then
      expect(shown.slice(1, 3)).toEqual(['· 0건: "결제"', "· 최근 저장 3건 (검색 결과 아님)"]);
      expect(shown.slice(3).filter((row) => /^\d+ /.test(row))).toHaveLength(3);
    });

    it("태그로찾아없을때_찾기결과를그리면_친태그그대로0건을보이는지", () => {
      // given
      // when
      const shown = shownOutput(noResults("#결제", [ready(131)]));

      // then
      expect(shown[1]).toBe('· 0건: "#결제"');
      expect(shown[2]).toBe("· 최근 저장 1건 (검색 결과 아님)");
    });

    it("찾은자료도최근자료도없을때_찾기결과를그리면_0건한줄만보이는지", () => {
      // given
      // when
      const shown = shownOutput(noResults("결제", []));

      // then
      expect(shown.slice(1)).toEqual(['· 0건: "결제"']);
    });
  });

  describe("상태줄·연결(#60, ARC-005·COM-010)", () => {
    it("처리중인자료가있을때_화면을그리면_상태줄에요약생성중N을보이는지", () => {
      // given
      // when
      const { container } = renderView({ itemCount: 131, processingCount: 2 });

      // then
      expect(container.querySelector(".gt-status")!.textContent).toContain("요약 생성 중 2");
    });

    it("처리중인자료가없을때_화면을그리면_상태줄에요약생성중을숨기는지", () => {
      // given
      // when
      const { container } = renderView({ itemCount: 131, processingCount: 0 });

      // then
      expect(container.querySelector(".gt-status")!.textContent).not.toContain("요약 생성 중");
    });

    it("연결이끊겼을때_화면을그리면_상태줄에연결끊김을보이는지", () => {
      // given
      // when
      const { container } = renderView({ isOffline: true });

      // then
      expect(container.querySelector(".gt-status")!.textContent).toContain("연결 끊김");
    });

    it("연결되어있을때_화면을그리면_상태줄에연결끊김이없는지", () => {
      // given
      // when
      const { container } = renderView({ isOffline: false });

      // then
      expect(container.querySelector(".gt-status")!.textContent).not.toContain("연결 끊김");
    });

    it("명령이서버에닿지못했을때_화면을그리면_명령안됨과다시칠명령을보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        { kind: "prompt", text: "최근" },
        { kind: "commandFailed", command: "recent", reason: "disconnected", retry: "최근" },
      ];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown.slice(1)).toEqual(["✗ 최근 안 됨: 연결 끊김", "→ 다시: 최근"]);
    });

    it("다시연결됐을때_화면을그리면_연결됨한줄을보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [{ kind: "reconnected" }];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown).toEqual(["✓ 연결됨"]);
    });
  });
});
