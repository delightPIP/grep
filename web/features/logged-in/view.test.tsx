import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { CommandFailure, ItemDetail, ItemSummary, LoggedInState, TerminalLine } from "../../support/view-state";
import { LoggedInView } from "./view";

afterEach(cleanup);

function renderView(state: Partial<LoggedInState> = {}) {
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
function shownLine(element: Element): string {
  return Array.from(element.children, (child) => child.textContent).join(" ");
}

/** 명령 출력 줄. 터미널 머리(두더지와 그 아래 안내)는 명령의 출력이 아니라 뺀다. */
function outputLines(container: HTMLElement): Element[] {
  return Array.from(container.querySelectorAll("[role=log] .gt-prompt, [role=log] .gt-line")).filter(
    (line) => line.closest(".gt-head") === null,
  );
}

function headLines(state: Partial<LoggedInState>): string[] {
  const { container } = renderView(state);
  return Array.from(container.querySelectorAll(".gt-head .gt-line"), shownLine);
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
    expect(outputLines(container).map(shownLine)).toEqual(["그렙 ~ $ ㅁㄴㅇ", "✗ 없는 명령: ㅁㄴㅇ", "→ 명령 목록: 도움말"]);
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

    it("찾기만쳤을때_화면을그리면_검색어없음과예시를보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        { kind: "prompt", text: "찾기" },
        { kind: "missingArgument", command: "seek" },
      ];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown[1]).toBe("✗ 검색어 없음  예: 찾기 결제");
    });

    it("태그이름없이샵만쳤을때_화면을그리면_태그없음과예시를보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [{ kind: "prompt", text: "찾기 #" }, { kind: "missingTag" }];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown[1]).toBe("✗ 태그 없음  예: 찾기 #결제");
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
      expect(shown.slice(1)).toEqual(["1건", "131 카페 텀블러 할인, 올겨울 캠페인 늘었다 2026-11-27 11:00", "요약 131", "→ 찾아두기 결제"]);
    });

    it("찾은자료가10건을넘을때_찾기결과를그리면_머리줄에전체중보인건수와더보기를보이는지", () => {
      // given
      const items = Array.from({ length: 10 }, (_, index) => ready(140 - index));

      // when
      const shown = shownOutput(found(23, items, true));

      // then
      expect(shown[1]).toBe("23건 중 10건");
      expect(shown.slice(-2)).toEqual(["→ 더 보기", "→ 찾아두기 결제"]);
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

  describe("고르기와 칩·번호 누르기(#62, ARC-001·commands 6절)", () => {
    const PICK = { kind: "prompt", text: "고르기 131 97" } as const;
    const PICKED = [
      { number: 131, title: "결제위젯 연동 가이드" },
      { number: 97, title: "PG사 수수료 비교 정리.pdf" },
    ];

    it("두건을골랐을때_화면을그리면_선택N건과제목과다음명령을보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [PICK, { kind: "picked", items: PICKED }];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown.slice(1)).toEqual([
        "✓ 선택 2건  결제위젯 연동 가이드 · PG사 수수료 비교 정리.pdf",
        "→ 넘기기 또는 묶음 <이름>",
      ]);
    });

    it("고른뒤일때_넘기기칩을누르면_입력줄에넘기기를찍기만하고입력줄로돌아가는지", () => {
      // given
      const { onInputChange, onSubmit, input } = renderView({ lines: [PICK, { kind: "picked", items: PICKED }] });

      // when
      fireEvent.click(screen.getByRole("button", { name: "넘기기" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("넘기기");
      expect(onSubmit).not.toHaveBeenCalled();
      expect(document.activeElement).toBe(input);
    });

    it("없는번호가섞였을때_화면을그리면_없는번호를쉼표로이어보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [PICK, { kind: "notFound", numbers: [57, 58] }];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown.slice(1)).toEqual(["✗ 없는 번호: 57, 58"]);
    });

    it("번호가양의정수가아닐때_화면을그리면_잘못된번호와예를보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [PICK, { kind: "invalidNumber", input: "0" }];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown.slice(1)).toEqual(["✗ 잘못된 번호: 0  예: 고르기 131 140"]);
    });

    it("번호를빠뜨렸을때_화면을그리면_번호없음과예를보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        { kind: "prompt", text: "고르기" },
        { kind: "missingArgument", command: "pick" },
      ];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown.slice(1)).toEqual(["✗ 번호 없음  예: 고르기 131"]);
    });

    it("선택이있을때_화면을그리면_상태줄자료다음에선택N을보이는지", () => {
      // given
      // when
      const { container } = renderView({ itemCount: 131, selection: PICKED, processingCount: 1 });

      // then
      expect(container.querySelector(".gt-status")!.textContent).toContain("자료 131· 선택 2· 요약 생성 중 1");
    });

    it("선택이없을때_화면을그리면_상태줄에선택을숨기는지", () => {
      // given
      // when
      const { container } = renderView({ itemCount: 131, selection: [] });

      // then
      expect(container.querySelector(".gt-status")!.textContent).not.toContain("선택");
    });

    it("선택이있을때_화면을그리면_입력줄위에선택줄을보이는지", () => {
      // given
      // when
      const { container } = renderView({ selection: PICKED });

      // then
      expect(container.querySelector(".gt-selection")!.textContent).toBe(
        "선택 2  결제위젯 연동 가이드 · PG사 수수료 비교 정리.pdf",
      );
    });

    it("선택이없을때_화면을그리면_선택줄이없는지", () => {
      // given
      // when
      const { container } = renderView({ selection: [] });

      // then
      expect(container.querySelector(".gt-selection")).toBeNull();
    });

    it("고른자료가목록에있을때_화면을그리면_그행번호앞에표시를다는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        { kind: "prompt", text: "최근" },
        { kind: "recentList", items: [item({ number: 131 }), item({ number: 130 })], hasMore: false },
      ];

      // when
      const { container } = renderView({ lines, selection: [{ number: 131, title: "t" }] });

      // then
      const numbers = Array.from(container.querySelectorAll(".gt-row-num"), (cell) => cell.textContent);
      expect(numbers).toEqual(["▸131", "130"]);
    });

    it("목록이있을때_행번호를누르면_입력줄에고르기번호를찍기만하는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        { kind: "prompt", text: "최근" },
        { kind: "recentList", items: [item({ number: 131 })], hasMore: false },
      ];
      const { onInputChange, onSubmit, input } = renderView({ lines });

      // when
      fireEvent.click(screen.getByRole("button", { name: "131" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("고르기 131");
      expect(onSubmit).not.toHaveBeenCalled();
      expect(document.activeElement).toBe(input);
    });

    it("이미저장된자료일때_고르기칩을누르면_입력줄에고르기번호를찍는지", () => {
      // given
      const { onInputChange } = renderView({ lines: [KEEP, { kind: "alreadySaved", item: item() }] });

      // when
      fireEvent.click(screen.getByRole("button", { name: "고르기 131" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("고르기 131");
    });
  });

  describe("넘기기 결과(#64, commands 6절·넘길 글 형식 3절)", () => {
    const HANDOFF = { kind: "prompt", text: "넘기기" } as const;
    const TEXT = "[그렙 · 자료 2건]\n\n131. 결제위젯 연동 가이드";

    function handedOff(missingSummaryCount = 0): LoggedInState["lines"] {
      return [
        HANDOFF,
        {
          kind: "handedOff",
          result: {
            items: [
              { number: 131, title: "결제위젯 연동 가이드" },
              { number: 97, title: "PG사 수수료 비교 정리.pdf" },
            ],
            charCount: 1240,
            missingSummaryCount,
            text: TEXT,
          },
        },
      ];
    }

    it("두건을넘겼을때_화면을그리면_복사됨건수글자수와자료줄과미리보기와붙여넣기안내를보이는지", () => {
      // given
      // when
      const shown = shownOutput(handedOff());

      // then
      expect(shown.slice(1)).toEqual([
        "✓ 복사됨  2건 · 1,240자 (제목·출처·저장 시각·요약)",
        "131 결제위젯 연동 가이드",
        "97 PG사 수수료 비교 정리.pdf",
        "· 미리보기: 펼치기",
        "· 클립보드에 있음 → AI 도구 입력창에 붙여 넣기",
      ]);
    });

    it("요약없는자료가있을때_화면을그리면_자료줄다음미리보기앞에요약없음N건을보이는지", () => {
      // given
      // when
      const shown = shownOutput(handedOff(1));

      // then
      expect(shown.slice(4, 6)).toEqual(["! 요약 없음 1건", "· 미리보기: 펼치기"]);
    });

    it("넘긴뒤일때_펼치기를누르면_입력줄을건드리지않고넘긴글전체와접기를보이는지", () => {
      // given
      const { container, onInputChange } = renderView({ lines: handedOff() });

      // when
      fireEvent.click(screen.getByRole("button", { name: "펼치기" }));

      // then
      expect(container.querySelector(".gt-preview")!.textContent).toBe(TEXT);
      expect(screen.getByRole("button", { name: "접기" })).toBeTruthy();
      expect(onInputChange).not.toHaveBeenCalled();
    });

    it("미리보기를펼쳤을때_접기를누르면_넘긴글을숨기는지", () => {
      // given
      const { container } = renderView({ lines: handedOff() });
      fireEvent.click(screen.getByRole("button", { name: "펼치기" }));

      // when
      fireEvent.click(screen.getByRole("button", { name: "접기" }));

      // then
      expect(container.querySelector(".gt-preview")).toBeNull();
    });

    it("넘긴뒤일때_자료번호를누르면_입력줄에고르기번호를찍는지", () => {
      // given
      const { onInputChange } = renderView({ lines: handedOff() });

      // when
      fireEvent.click(screen.getByRole("button", { name: "97" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("고르기 97");
    });
  });

  describe("넘기기 실패(#65, COM-008)", () => {
    const HANDOFF = { kind: "prompt", text: "넘기기" } as const;
    const TEXT = "[그렙 · 자료 2건]\n\n131. 결제위젯 연동 가이드";
    const originalPlatform = navigator.platform;

    afterEach(() => {
      Object.defineProperty(navigator, "platform", { value: originalPlatform, configurable: true });
    });

    function failed(reason: CommandFailure, preview: string | null = null): LoggedInState["lines"] {
      return [HANDOFF, { kind: "handoffFailed", reason, preview }];
    }

    it.each([
      ["disconnected", "연결 끊김"],
      ["timedOut", "응답 없음"],
      ["serverError", "서버 오류"],
    ] as const)("%s로실패했을때_화면을그리면_복사안됨이유와선택남김과넘기기만안내하는지", (reason, label) => {
      // given
      // when
      const shown = shownOutput(failed(reason));

      // then
      expect(shown.slice(1)).toEqual([`✗ 복사 안 됨: ${label}  선택은 남겨 둠`, "→ 넘기기"]);
    });

    it("서버오류로실패했을때_넘기기칩을누르면_입력줄에넘기기를찍는지", () => {
      // given
      const { onInputChange } = renderView({ lines: failed("serverError") });

      // when
      fireEvent.click(screen.getByRole("button", { name: "넘기기" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("넘기기");
    });

    it("클립보드가거부됐을때_화면을그리면_펼친미리보기와직접복사키와다시넘기기를보이는지", () => {
      // given
      // when
      const { container } = renderView({ lines: failed("clipboardDenied", TEXT) });

      // then
      expect(outputLines(container).slice(1).map(shownLine)).toEqual([
        "✗ 복사 안 됨: 클립보드 거부  선택은 남겨 둠",
        "→ 직접 복사: Ctrl+C · 다시: 넘기기",
      ]);
      expect(container.querySelector(".gt-preview")!.textContent).toBe(TEXT);
    });

    it("클립보드가거부됐을때_화면을그리면_미리보기전체를선택해두는지", () => {
      // given
      // when
      renderView({ lines: failed("clipboardDenied", TEXT) });

      // then
      expect(window.getSelection()!.toString()).toBe(TEXT);
    });

    it("macOS에서클립보드가거부됐을때_화면을그리면_직접복사키를커맨드C로안내하는지", () => {
      // given
      Object.defineProperty(navigator, "platform", { value: "MacIntel", configurable: true });

      // when
      const shown = shownOutput(failed("clipboardDenied", TEXT));

      // then
      expect(shown[2]).toBe("→ 직접 복사: ⌘C · 다시: 넘기기");
    });
  });

  describe("넘기기 확인 대기(#66, COM-007·COM-008)", () => {
    function confirm(total: number): LoggedInState["lines"] {
      return [{ kind: "prompt", text: "넘기기" }, { kind: "handoffConfirm", total }];
    }

    it("6건일때_화면을그리면_바로복사안함과전부만묻는지", () => {
      // given
      // when
      const shown = shownOutput(confirm(6));

      // then
      expect(shown.slice(1)).toEqual(["! 6건: 바로 복사 안 함 (5건 초과)", "→ 전부: 6건 전부 · 취소: 그 외 입력"]);
    });

    it("10건일때_화면을그리면_앞10없이전부만묻는지", () => {
      // given
      // when
      const shown = shownOutput(confirm(10));

      // then
      expect(shown[2]).toBe("→ 전부: 10건 전부 · 취소: 그 외 입력");
    });

    it("11건일때_화면을그리면_앞10과전부를묻는지", () => {
      // given
      // when
      const shown = shownOutput(confirm(11));

      // then
      expect(shown.slice(1)).toEqual([
        "! 11건: 바로 복사 안 함 (5건 초과)",
        "→ 앞10: 앞 10건만 · 전부: 11건 전부 · 취소: 그 외 입력",
      ]);
    });

    it("확인을기다릴때_앞10칩을누르면_입력줄에앞10을찍기만하는지", () => {
      // given
      const { onInputChange, onSubmit } = renderView({ lines: confirm(23) });

      // when
      fireEvent.click(screen.getByRole("button", { name: "앞10" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("앞10");
      expect(onSubmit).not.toHaveBeenCalled();
    });

    it("확인을기다릴때_전부칩을누르면_입력줄에전부를찍는지", () => {
      // given
      const { onInputChange } = renderView({ lines: confirm(23) });

      // when
      fireEvent.click(screen.getByRole("button", { name: "전부" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("전부");
    });

    it("확인이취소됐을때_화면을그리면_취소됨한줄을보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [...confirm(23), { kind: "prompt", text: "" }, { kind: "cancelled" }];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown.at(-1)).toBe("· 취소됨");
    });
  });

  describe("첫 화면·도움말(#67, commands 2절·6절)", () => {
    it("자료가0건일때_첫화면을그리면_한문장과표어를보이는지", () => {
      // given
      // when
      const { container } = renderView({ itemCount: 0, lines: [{ kind: "welcome" }] });

      // then
      const banner = container.querySelector(".gt-banner")!.textContent;
      expect(banner).toContain("저장해 둔 링크·캡처·PDF를 찾아 AI 도구에 붙여 넣을 글로 복사");
      expect(banner).toContain("담기 → 찾기 → 넘기기");
    });

    it("첫화면줄없이자료가있을때_터미널을그리면_출력맨위에두더지머리를보이는지", () => {
      // given
      // when
      const { container } = renderView({ itemCount: 4, lines: [{ kind: "prompt", text: "최근" }] });

      // then
      const banners = container.querySelectorAll(".gt-banner");
      expect(banners).toHaveLength(1);
      expect(banners[0].textContent).toContain("담기 → 찾기 → 넘기기");
      expect(container.querySelector(".gt-mascot")).not.toBeNull();
      expect(container.textContent).not.toContain("자료 0건");
    });

    it("첫화면줄없이자료가있을때_터미널을그리면_머리아래에자료건수와명령전체안내를보이는지", () => {
      // given
      // when
      const shown = headLines({ itemCount: 1234 });

      // then
      expect(shown).toEqual(["· 자료 1,234건", "· 명령 전체: 도움말"]);
    });

    it("자료수를아직받지못했을때_터미널을그리면_건수줄없이명령전체안내만보이는지", () => {
      // given
      // when
      const shown = headLines({ itemCount: null });

      // then
      expect(shown).toEqual(["· 명령 전체: 도움말"]);
    });

    it("찍힌줄이없을때_터미널을그리면_두더지머리만보이는지", () => {
      // given
      // when
      const { container } = renderView({ itemCount: 4, lines: [] });

      // then
      expect(container.querySelectorAll(".gt-banner")).toHaveLength(1);
    });

    it("첫화면줄이있을때_터미널을그리면_두더지머리를두번그리지않는지", () => {
      // given
      // when
      const { container } = renderView({ itemCount: 0, lines: [{ kind: "welcome" }, { kind: "prompt", text: "도움말" }] });

      // then
      expect(container.querySelectorAll(".gt-banner")).toHaveLength(1);
    });

    it("자료가0건일때_첫화면을그리면_자료0건과샘플안내와명령전체안내를보이고13줄표는없는지", () => {
      // given
      // when
      const shown = shownOutput([{ kind: "welcome" }]);

      // then
      expect(shown).toEqual([
        "· 자료 0건",
        "→ 샘플 8건으로 해 보기 또는 아래에 링크 붙여 넣기",
        "· 명령 전체: 도움말",
      ]);
    });

    it("첫화면일때_도움말칩을누르면_입력줄에도움말을찍기만하는지", () => {
      // given
      const { onInputChange, onSubmit } = renderView({ lines: [{ kind: "welcome" }] });

      // when
      fireEvent.click(screen.getByRole("button", { name: "도움말" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("도움말");
      expect(onSubmit).not.toHaveBeenCalled();
    });

    it("도움말을쳤을때_화면을그리면_안내줄과명령18줄과예시줄을보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [{ kind: "prompt", text: "도움말" }, { kind: "guide" }];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown.slice(1)).toEqual([
        "저장: 링크·글 붙여 넣기, 파일 끌어다 놓기. 명령: 한글·영문 같음",
        "담기 keep 자료 저장",
        "최근 recent 최근 자료 목록",
        "찾기 seek 검색",
        "열기 peek 자료 자세히 보기",
        "찾아두기 gather 검색어 저장",
        "고르기 pick 번호로 선택",
        "넘기기 handoff AI 도구용 글 복사",
        "묶음 pack 선택에 이름 붙이기",
        "고치기 revise 제목·요약 수정",
        "버리기 drop 삭제",
        "되살리기 revive 휴지통에서 돌리기",
        "휴지통 bin 휴지통 목록",
        "휴지통 비우기 bin empty 휴지통 영구 삭제",
        "가져오기 bring 북마크 파일 가져오기",
        "연결 plug AI 도구 연결",
        "로그아웃 signout 로그아웃",
        "도움말 guide 명령 목록",
        "설명 about 명령 설명",
        "→ 예: 찾기 결제 | 넘기기 · 자세히: 설명 찾기",
      ]);
    });

    it("도움말을쳤을때_예시칩을누르면_입력줄에그명령을찍는지", () => {
      // given
      const { onInputChange } = renderView({ lines: [{ kind: "guide" }] });

      // when
      fireEvent.click(screen.getByRole("button", { name: "찾기 결제 | 넘기기" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("찾기 결제 | 넘기기");
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

  describe("버리기·되살리기 결과(#93, ARC-008)", () => {
    it("1건을버렸을때_화면을그리면_휴지통건수와되살리기번호를보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        { kind: "prompt", text: "버리기 131" },
        { kind: "dropped", items: [{ number: 131, title: "결제 오류 정리" }] },
      ];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown[1]).toBe("✓ 휴지통 1건 (30일 뒤 삭제, 되살리기 131)");
    });

    it("여러건을버렸을때_화면을그리면_되살리기에번호를모두보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        { kind: "prompt", text: "버리기" },
        {
          kind: "dropped",
          items: [
            { number: 131, title: "결제 오류 정리" },
            { number: 57, title: "환불 규정" },
          ],
        },
      ];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown[1]).toBe("✓ 휴지통 2건 (30일 뒤 삭제, 되살리기 131 57)");
    });

    it("되살렸을때_화면을그리면_되살림건수를보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        { kind: "prompt", text: "되살리기 131 57" },
        {
          kind: "revived",
          items: [
            { number: 131, title: "결제 오류 정리" },
            { number: 57, title: "환불 규정" },
          ],
        },
      ];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown[1]).toBe("✓ 되살림 2건");
    });
  });

  describe("버리기 확인·휴지통 목록·비우기(#96, ARC-008·COM-007)", () => {
    function trashed(number: number, overrides: Partial<ItemSummary> = {}, daysLeft = 30) {
      return { item: item({ number, ...overrides }), trashedAt: "2026-11-27T02:00:00Z", daysLeft };
    }

    it("2건이상버리려할때_화면을그리면_건수확인과실행낱말을묻는지", () => {
      // given
      const lines: LoggedInState["lines"] = [{ kind: "prompt", text: "버리기 21 29" }, { kind: "dropConfirm", total: 2 }];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown.slice(1)).toEqual(["! 버리기? 2건 (휴지통으로)", "→ 실행: 버리기 다시 입력 · 취소: 그 외 입력"]);
    });

    it("버리기확인을기다릴때_버리기칩을누르면_입력줄에버리기를찍기만하는지", () => {
      // given
      const { onInputChange, onSubmit } = renderView({ lines: [{ kind: "dropConfirm", total: 3 }] });

      // when
      fireEvent.click(screen.getByRole("button", { name: "버리기" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("버리기");
      expect(onSubmit).not.toHaveBeenCalled();
    });

    it("휴지통을쳤을때_화면을그리면_건수머리와남은날칸과다음명령을보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        { kind: "prompt", text: "휴지통" },
        {
          kind: "binList",
          total: 2,
          items: [
            trashed(29, { title: "주간 업무 메모.md", source: "md" }),
            trashed(21, { title: "사무실 비품 주문 목록.txt", source: "txt" }, 3),
          ],
          hasMore: false,
        },
      ];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown.slice(1)).toEqual([
        "2건",
        "29 주간 업무 메모.md md 30일 남음",
        "21 사무실 비품 주문 목록.txt txt 3일 남음",
        "→ 되살리기 또는 휴지통 비우기",
      ]);
    });

    it("휴지통에다음쪽이남았을때_화면을그리면_머리에보인건수와더보기를보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        { kind: "binList", total: 12, items: [trashed(29, { source: null })], hasMore: true },
      ];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown[0]).toBe("12건 중 1건");
      expect(shown).toContain("→ 더 보기");
    });

    it("휴지통목록일때_되살리기칩을누르면_입력줄에되살리기와빈칸을찍는지", () => {
      // given
      const { onInputChange } = renderView({
        lines: [{ kind: "binList", total: 1, items: [trashed(29)], hasMore: false }],
      });

      // when
      fireEvent.click(screen.getByRole("button", { name: "되살리기" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("되살리기 ");
    });

    it("휴지통을비우려할때_화면을그리면_되돌릴수없음과실행낱말을묻는지", () => {
      // given
      const lines: LoggedInState["lines"] = [{ kind: "prompt", text: "휴지통 비우기" }, { kind: "binEmptyConfirm", total: 2 }];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown.slice(1)).toEqual(["! 비우기? 2건 (되돌릴 수 없음)", "→ 실행: 비우기 다시 입력 · 취소: 그 외 입력"]);
    });

    it("휴지통이비었을때_비우기결과가오면_비어있음줄을그리는지", () => {
      // given
      const lines: LoggedInState["lines"] = [{ kind: "prompt", text: "휴지통 비우기" }, { kind: "binEmptied", count: 0 }];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown.slice(1)).toEqual(["· 휴지통 비어 있음"]);
    });

    it("휴지통이비었을때_휴지통을치면_비어있음한줄만그리는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        { kind: "prompt", text: "휴지통" },
        { kind: "binList", total: 0, items: [], hasMore: false },
      ];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown.slice(1)).toEqual(["· 휴지통 비어 있음"]);
    });

    it("휴지통을비웠을때_화면을그리면_영구삭제건수를보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [{ kind: "prompt", text: "비우기" }, { kind: "binEmptied", count: 2 }];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown[1]).toBe("✓ 비움  2건 영구 삭제");
    });
  });

  describe("고치기 편집·결과(#99, ARC-002·ARC-004·화면 W24)", () => {
    const REVISING = { number: 25, title: "겨울 음료 트렌드 보고서.pdf", summary: "겨울 음료 수요 정리" };

    it("고치는중일때_화면을그리면_머리줄과두칸과키안내를보이고제목칸에초점을두는지", () => {
      // given
      const { container } = renderView({ lines: [{ kind: "prompt", text: "고치기 25" }], revising: REVISING });

      // when
      const title = screen.getByRole("textbox", { name: "제목" }) as HTMLInputElement;
      const summary = screen.getByRole("textbox", { name: "요약 (직접 고침)" }) as HTMLInputElement;

      // then
      expect(outputLines(container).map(shownLine)).toContain("· 고치기 25  겨울 음료 트렌드 보고서.pdf");
      expect(title.value).toBe(REVISING.title);
      expect(summary.value).toBe(REVISING.summary);
      expect(document.activeElement).toBe(title);
      expect(container.textContent).toContain("Enter: 저장 · Esc: 취소 · Tab: 다음 칸");
    });

    it("고치지않을때_화면을그리면_편집칸이없는지", () => {
      // given
      renderView({ revising: null });

      // when
      const title = screen.queryByRole("textbox", { name: "제목" });

      // then
      expect(title).toBeNull();
    });

    it("두칸을고쳤을때_엔터를누르면_번호와고친제목요약을보내는지", () => {
      // given
      const { onReviseSubmit, onSubmit } = renderView({ revising: REVISING });
      const title = screen.getByRole("textbox", { name: "제목" });
      const summary = screen.getByRole("textbox", { name: "요약 (직접 고침)" });
      fireEvent.change(title, { target: { value: "겨울 음료 보고서" } });
      fireEvent.change(summary, { target: { value: "3쪽 표가 핵심" } });

      // when
      fireEvent.keyDown(summary, { key: "Enter" });

      // then
      expect(onReviseSubmit).toHaveBeenCalledWith(25, "겨울 음료 보고서", "3쪽 표가 핵심");
      expect(onSubmit).not.toHaveBeenCalled();
    });

    it("고치기가끝났을때_편집칸이닫히면_명령입력줄로초점을돌려놓는지", () => {
      // given
      const props = {
        itemCount: null, lines: [], input: "", selection: [], processingCount: 0, isOffline: false,
        onInputChange: vi.fn(), onSubmit: vi.fn(), onPaste: vi.fn(), onFilesDrop: vi.fn(),
      };
      const { rerender } = render(<LoggedInView {...props} revising={REVISING} />);

      // when
      rerender(<LoggedInView {...props} revising={null} />);

      // then
      expect(document.activeElement).toBe(screen.getByRole("textbox", { name: "명령 입력" }));
    });

    it("한글을조합하는중일때_엔터를누르면_저장하지않는지", () => {
      // given
      const { onReviseSubmit } = renderView({ revising: REVISING });

      // when
      fireEvent.keyDown(screen.getByRole("textbox", { name: "제목" }), { key: "Enter", isComposing: true });

      // then
      expect(onReviseSubmit).not.toHaveBeenCalled();
    });

    it("고치는중일때_Esc를누르면_취소를알리고저장하지않는지", () => {
      // given
      const { onReviseSubmit, onReviseCancel } = renderView({ revising: REVISING });

      // when
      fireEvent.keyDown(screen.getByRole("textbox", { name: "요약 (직접 고침)" }), { key: "Escape" });

      // then
      expect(onReviseCancel).toHaveBeenCalledTimes(1);
      expect(onReviseSubmit).not.toHaveBeenCalled();
    });

    it("요약을직접고쳐저장했을때_화면을그리면_고침줄과직접고침이름표를보이는지", () => {
      // given
      const revised = item({ number: 25, title: "겨울 음료 보고서", listSummary: "3쪽 표가 핵심", summarySource: "user" });
      const lines: LoggedInState["lines"] = [{ kind: "prompt", text: "고치기 25" }, { kind: "revised", item: revised }];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown.slice(1)).toEqual(["✓ 고침 25번  겨울 음료 보고서", "요약 (직접 고침)  3쪽 표가 핵심"]);
    });

    it("제목만고쳐AI요약이남았을때_화면을그리면_직접고침이름표를붙이지않는지", () => {
      // given
      const revised = item({ number: 25, title: "겨울 음료 보고서", summarySource: "ai" });

      // when
      const shown = shownOutput([{ kind: "revised", item: revised }]);

      // then
      expect(shown).toEqual(["✓ 고침 25번  겨울 음료 보고서"]);
    });

    it("태그를지웠을때_화면을그리면_지운태그와번호를보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        { kind: "prompt", text: "고치기 25 -#할인" },
        { kind: "tagsRemoved", item: item({ number: 25 }), tags: ["할인"] },
      ];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown[1]).toBe("✓ 태그 지움 #할인 (25번)");
    });
  });

  describe("샘플 8건(#102, ARC-010)", () => {
    it("첫화면일때_샘플칩을누르면_입력줄을거치지않고바로샘플을요청하는지", () => {
      // given
      const { onSamplesRequest, onInputChange } = renderView({ lines: [{ kind: "welcome" }] });

      // when
      fireEvent.click(screen.getByRole("button", { name: "샘플 8건으로 해 보기" }));

      // then
      expect(onSamplesRequest).toHaveBeenCalledTimes(1);
      expect(onInputChange).not.toHaveBeenCalled();
    });

    it("샘플을받았을때_화면을그리면_받은범위와치우는명령과목록을보이는지", () => {
      // given
      const items = [item({ number: 15, title: "샘플 둘", source: null }), item({ number: 8, title: "샘플 하나", source: null })];
      const lines: LoggedInState["lines"] = [{ kind: "samplesSaved", firstNumber: 8, lastNumber: 15, items }];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown.slice(0, 2)).toEqual(["✓ 샘플 8건 저장 (8-15번)", "· 치우려면: 버리기 8-15"]);
      expect(shown[2]).toMatch(/^15 샘플 둘 /);
    });

    it("샘플을받았을때_치우는명령칩을누르면_입력줄에버리기범위를찍기만하는지", () => {
      // given
      const { onInputChange, onSubmit } = renderView({
        lines: [{ kind: "samplesSaved", firstNumber: 1, lastNumber: 8, items: [] }],
      });

      // when
      fireEvent.click(screen.getByRole("button", { name: "버리기 1-8" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("버리기 1-8");
      expect(onSubmit).not.toHaveBeenCalled();
    });
  });

  describe("고르기 빼기·비우기(#108, commands 6절)", () => {
    it("고르기빼기를번호없이쳤을때_화면을그리면_빼기예시를보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        { kind: "prompt", text: "고르기 빼기" },
        { kind: "missingArgument", command: "pick", sub: "unpick" },
      ];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown.slice(1)).toEqual(["✗ 번호 없음  예: 고르기 빼기 131"]);
    });

    it("선택에서뺐을때_화면을그리면_그때남은선택건수를보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        { kind: "prompt", text: "고르기 빼기 140" },
        { kind: "unpicked", items: [{ number: 140, title: "환불 규정" }], remaining: 2 },
      ];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown.slice(1)).toEqual(["✓ 뺌  선택 2건 남음"]);
    });

    it("선택을모두풀었을때_화면을그리면_선택비움한줄을보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [{ kind: "prompt", text: "고르기 비우기" }, { kind: "pickCleared", count: 3 }];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown.slice(1)).toEqual(["✓ 선택 비움"]);
    });
  });

  describe("모든 기기 로그아웃 확인(#111, ACC-002·COM-007)", () => {
    it("로그아웃모든기기를쳤을때_화면을그리면_다른기기반영시간과실행낱말을묻는지", () => {
      // given
      const lines: LoggedInState["lines"] = [{ kind: "prompt", text: "로그아웃 모든기기" }, { kind: "signOutEverywhereConfirm" }];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown.slice(1)).toEqual([
        "! 로그아웃? 모든 기기 (다른 기기는 최대 1시간 뒤)",
        "→ 실행: 로그아웃 다시 입력 · 취소: 그 외 입력",
      ]);
    });
  });

  describe("시점 머리 줄·주 구분선(#114, user-flow 5절 3번·commands 3절 시점)", () => {
    // 한국 시간 10/1 00:00 ~ 11/1 00:00(반열린 구간)
    const LAST_MONTH = { label: "지난달", from: "2026-09-30T15:00:00Z", to: "2026-10-31T15:00:00Z" };
    // 한국 시간 11/16(월) 00:00 ~ 11/23(월) 00:00
    const LAST_WEEK = { label: "지난주", from: "2026-11-15T15:00:00Z", to: "2026-11-22T15:00:00Z" };
    const savedOn = (number: number, savedAt: string) =>
      item({ number, title: `자료 ${number}`, source: null, savedAt, status: "ready", listSummary: null, tags: [] });

    it("최근에시점이붙고여러주에걸칠때_화면을그리면_건수머리와주마다구분선을보이는지", () => {
      // given
      const items = [
        savedOn(9, "2026-10-30T01:00:00Z"),
        savedOn(6, "2026-10-25T16:00:00Z"), // 한국 시간 10/26(월) 01:00
        savedOn(5, "2026-10-25T14:00:00Z"), // 한국 시간 10/25(일) 23:00
      ];
      const lines: LoggedInState["lines"] = [
        { kind: "prompt", text: "최근 지난달" },
        { kind: "recentList", items, hasMore: false, period: LAST_MONTH },
      ];

      // when
      const shown = shownOutput(lines).slice(1);

      // then
      expect(shown[0]).toBe("3건 · 지난달 (10/1~10/31)");
      expect(shown[1]).toBe("── 10/26~11/1 ──");
      expect(shown[2]).toMatch(/^9 자료 9 /);
      expect(shown[3]).toMatch(/^6 자료 6 /);
      expect(shown[4]).toBe("── 10/19~10/25 ──");
      expect(shown[5]).toMatch(/^5 자료 5 /);
    });

    it("시점이한주안일때_화면을그리면_구분선없이머리만보이는지", () => {
      // given
      const items = [savedOn(12, "2026-11-20T03:00:00Z"), savedOn(11, "2026-11-16T03:00:00Z")];

      // when
      const shown = shownOutput([{ kind: "recentList", items, hasMore: false, period: LAST_WEEK }]);

      // then
      expect(shown[0]).toBe("2건 · 지난주 (11/16~11/22)");
      expect(shown.some((line) => line.startsWith("──"))).toBe(false);
    });

    it("최근에시점이붙고10건을넘을때_화면을그리면_전체중보인건수를머리에보이는지", () => {
      // given
      const items = [savedOn(9, "2026-10-30T01:00:00Z")];

      // when
      const shown = shownOutput([{ kind: "recentList", items, hasMore: true, period: LAST_MONTH, total: 23 }]);

      // then
      expect(shown[0]).toBe("23건 중 1건 · 지난달 (10/1~10/31)");
    });

    it("찾기에시점이붙고다음쪽이남았을때_화면을그리면_전체중보인건수와시점을한머리에보이는지", () => {
      // given
      const items = [savedOn(9, "2026-10-30T01:00:00Z")];

      // when
      const shown = shownOutput([
        { kind: "searchResult", query: { text: "결제 지난달", words: "결제", tags: [] }, total: 23, items, hasMore: true, period: LAST_MONTH },
      ]);

      // then
      expect(shown[0]).toBe("23건 중 1건 · 지난달 (10/1~10/31)");
    });
  });

  describe("오타 제안(#118, commands 5절)", () => {
    it("가까운명령이있을때_화면을그리면_없는명령다음줄에고친입력을묻는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        { kind: "prompt", text: "찻기 결제" },
        { kind: "unknownCommand", name: "찻기", suggestion: "찾기 결제" },
      ];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown.slice(1)).toEqual(["✗ 없는 명령: 찻기", "→ 찾기 결제?"]);
    });

    it("제안이떠있을때_제안칩을누르면_입력줄에고친입력을찍기만하는지", () => {
      // given
      const { onInputChange, onSubmit } = renderView({
        lines: [{ kind: "unknownCommand", name: "찻기", suggestion: "찾기 결제" }],
      });

      // when
      fireEvent.click(screen.getByRole("button", { name: "찾기 결제" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("찾기 결제");
      expect(onSubmit).not.toHaveBeenCalled();
    });
  });

  describe("시점을 붙인 찾기 0건(#114, commands 6절)", () => {
    const LAST_MONTH = { label: "지난달", from: "2026-09-30T15:00:00Z", to: "2026-10-31T15:00:00Z" };

    it("시점을붙인찾기가0건일때_화면을그리면_시점을밝히고기간없이다시찾기를권하는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        { kind: "prompt", text: "찾기 결제 #위젯 지난달" },
        {
          kind: "noResults",
          query: { text: "결제 #위젯 지난달", words: "결제", tags: ["위젯"] },
          recent: [],
          period: LAST_MONTH,
        },
      ];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown.slice(1)).toEqual(['· 0건: "결제 #위젯" (지난달)', "→ 기간 없이: 찾기 결제 #위젯"]);
    });

    it("시점이있는0건일때_기간없이칩을누르면_입력줄에찍기만하는지", () => {
      // given
      const { onInputChange } = renderView({
        lines: [{ kind: "noResults", query: { text: "결제 지난달", words: "결제", tags: [] }, recent: [], period: LAST_MONTH }],
      });

      // when
      fireEvent.click(screen.getByRole("button", { name: "찾기 결제" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("찾기 결제");
    });
  });

  describe("묶음 줄(#121, ARC-003)", () => {
    function shownBlock(prompt: string, line: TerminalLine): string[] {
      return shownOutput([{ kind: "prompt", text: prompt }, line]).slice(1);
    }

    it("묶음이있을때_묶음을치면_묶음수머리와이름별건수를보이는지", () => {
      // given
      const line: TerminalLine = {
        kind: "bundleList",
        bundles: [
          { name: "겨울캠페인", count: 3 },
          { name: "결제조사", count: 0 },
        ],
      };

      // when
      const shown = shownBlock("묶음", line);

      // then
      expect(shown).toEqual(["2개 묶음", "겨울캠페인 3건", "결제조사 0건"]);
    });

    it("묶음목록일때_묶음이름을누르면_입력줄에묶음이름을찍기만하는지", () => {
      // given
      const { onInputChange, onSubmit } = renderView({
        lines: [{ kind: "bundleList", bundles: [{ name: "겨울캠페인", count: 3 }] }],
      });

      // when
      fireEvent.click(screen.getByRole("button", { name: "겨울캠페인" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("묶음 겨울캠페인");
      expect(onSubmit).not.toHaveBeenCalled();
    });

    it("묶음이없을때_묶음을치면_묶음0개와고르기묶음을줄나눠안내하는지", () => {
      // given
      // when
      const shown = shownBlock("묶음", { kind: "bundleList", bundles: [] });

      // then
      expect(shown).toEqual(["· 묶음 0개", "→ 고르기 <번호>", "→ 묶음 <이름>"]);
    });

    it("묶음이없을때_고르기칩을누르면_입력줄에고르기와빈칸을찍는지", () => {
      // given
      const { onInputChange } = renderView({ lines: [{ kind: "bundleList", bundles: [] }] });

      // when
      fireEvent.click(screen.getByRole("button", { name: "고르기 <번호>" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("고르기 ");
    });

    it("선택을묶음에넣었을때_화면을그리면_건수와다음부터넘기기를보이는지", () => {
      // given
      // when
      const shown = shownBlock("묶음 겨울캠페인", { kind: "bundleAdded", name: "겨울캠페인", count: 3, alreadyCount: 0 });

      // then
      expect(shown).toEqual(["✓ 묶음 겨울캠페인: 3건", "→ 다음부터: 넘기기 겨울캠페인"]);
    });

    it("이미든자료를다시넣었을때_화면을그리면_이미있음건수를붙이는지", () => {
      // given
      // when
      const shown = shownBlock("묶음 겨울캠페인", { kind: "bundleAdded", name: "겨울캠페인", count: 3, alreadyCount: 1 });

      // then
      expect(shown[0]).toBe("✓ 묶음 겨울캠페인: 3건 (이미 있음 1건)");
    });

    it("선택없이묶음이름을쳤을때_화면을그리면_묶음머리와자료목록을보이는지", () => {
      // given
      const line: TerminalLine = {
        kind: "bundleView",
        name: "겨울캠페인",
        total: 2,
        items: [item({ number: 30, status: "ready" }), item({ number: 28, status: "ready" })],
        hasMore: false,
      };

      // when
      const shown = shownBlock("묶음 겨울캠페인", line);

      // then
      expect(shown[0]).toBe("묶음 겨울캠페인  2건");
      expect(shown.filter((text) => /^(30|28) /.test(text))).toHaveLength(2);
    });

    it("묶음안자료가한쪽을넘을때_화면을그리면_머리에보인건수와더보기를보이는지", () => {
      // given
      const line: TerminalLine = { kind: "bundleView", name: "겨울캠페인", total: 12, items: [item({ number: 30 })], hasMore: true };

      // when
      const shown = shownBlock("묶음 겨울캠페인", line);

      // then
      expect(shown[0]).toBe("묶음 겨울캠페인  12건 중 1건");
      expect(shown).toContain("→ 더 보기");
    });

    it("없는묶음을봤을때_화면을그리면_없는묶음과묶음칩을보이는지", () => {
      // given
      // when
      const shown = shownBlock("묶음 없는묶음", { kind: "bundleNotFound", name: "없는묶음" });

      // then
      expect(shown).toEqual(["✗ 없는 묶음: 없는묶음  → 묶음"]);
    });

    it("묶음에서뺐을때_화면을그리면_남은건수를보이는지", () => {
      // given
      // when
      const shown = shownBlock("묶음 겨울캠페인 빼기 30", { kind: "bundleUnpicked", name: "겨울캠페인", remaining: 2 });

      // then
      expect(shown).toEqual(["✓ 뺌  묶음 겨울캠페인: 2건 남음"]);
    });

    it("묶음에없는번호를뺄때_화면을그리면_그번호들을보이는지", () => {
      // given
      // when
      const shown = shownBlock("묶음 겨울캠페인 빼기 57 58", { kind: "notInBundle", name: "겨울캠페인", numbers: [57, 58] });

      // then
      expect(shown).toEqual(["✗ 묶음에 없음: 57, 58"]);
    });

    it("묶음을지우려할때_화면을그리면_남는자료수와실행낱말을묻는지", () => {
      // given
      // when
      const shown = shownBlock("묶음 겨울캠페인 지우기", { kind: "bundleDeleteConfirm", name: "겨울캠페인", itemCount: 2 });

      // then
      expect(shown).toEqual(["! 지우기? 묶음 겨울캠페인 (자료 2건은 남음)", "→ 실행: 지우기 다시 입력 · 취소: 그 외 입력"]);
    });

    it("묶음을지웠을때_화면을그리면_삭제됨과묶음이름을보이는지", () => {
      // given
      // when
      const shown = shownBlock("지우기", { kind: "bundleDeleted", name: "겨울캠페인" });

      // then
      expect(shown).toEqual(["✓ 삭제됨  묶음 겨울캠페인"]);
    });

    it("묶음이름이글자규칙에안맞을때_화면을그리면_이름규칙을알리는지", () => {
      // given
      // when
      const shown = shownBlock("묶음 겨울 캠페인", { kind: "bundleNameInvalid", reason: "format" });

      // then
      expect(shown).toEqual(["✗ 묶음 이름: 띄어쓰기 없이 1~20자 (한글·영문·숫자·-·_)"]);
    });

    it("묶음이름이금지이름일때_화면을그리면_금지이름을알리는지", () => {
      // given
      // when
      const shown = shownBlock("묶음 131", { kind: "bundleNameInvalid", reason: "reserved" });

      // then
      expect(shown).toEqual(["✗ 묶음 이름: 숫자만 · #시작 · 빼기 · 지우기 불가"]);
    });

    it("묶음을넘길때지운자료가있으면_화면을그리면_복사됨앞에빠진자료건수를보이는지", () => {
      // given
      const line: TerminalLine = {
        kind: "handedOff",
        result: {
          items: [{ number: 30, title: "카페 텀블러 할인" }],
          bundle: "겨울캠페인",
          removedCount: 1,
          charCount: 240,
          missingSummaryCount: 0,
          text: "[그렙 · 자료 1건]",
        },
      };

      // when
      const shown = shownBlock("넘기기 겨울캠페인", line);

      // then
      expect(shown.slice(0, 2)).toEqual(["! 빠진 자료 1건 (삭제됨)", "✓ 복사됨  1건 · 240자 (제목·출처·저장 시각·요약)"]);
    });

    it("고른뒤일때_묶음칩을누르면_입력줄에묶음과빈칸을찍는지", () => {
      // given
      const { onInputChange } = renderView({ lines: [{ kind: "picked", items: [{ number: 131, title: "결제위젯 연동 가이드" }] }] });

      // when
      fireEvent.click(screen.getByRole("button", { name: "묶음 <이름>" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("묶음 ");
    });
  });

  describe("자세히 보기(#131, ARC-011)", () => {
    function detail(overrides: Partial<ItemDetail> = {}, itemOverrides: Partial<ItemSummary> = {}): ItemDetail {
      return {
        item: item({
          number: 131,
          title: "결제위젯 연동 가이드",
          source: "docs.tosspayments.com",
          status: "ready",
          summarySource: "ai",
          savedAt: "2026-11-26T05:03:00Z",
          ...itemOverrides,
        }),
        handoffSummary: "결제위젯을 붙이는 순서를 정리한 문서.",
        allTags: ["결제", "위젯", "연동", "가이드"],
        bundles: ["결제조사"],
        bodyLength: 3420,
        body: "결제위젯 본문",
        bodyFromImage: false,
        url: "https://docs.tosspayments.com/guides/widget",
        originalUrl: null,
        previewUrl: null,
        ...overrides,
      };
    }

    function shownDetail(value: ItemDetail): string[] {
      return shownOutput([{ kind: "prompt", text: `열기 ${value.item.number}` }, { kind: "itemDetail", detail: value }]).slice(1);
    }

    it("링크자료를열었을때_화면을그리면_정책차례대로머리출처저장요약태그묶음본문다음명령을보이는지", () => {
      // given
      // when
      const shown = shownDetail(detail());

      // then
      expect(shown).toEqual([
        "131 결제위젯 연동 가이드",
        "출처 docs.tosspayments.com",
        "저장 2026-11-26 14:03",
        "AI 요약 결제위젯을 붙이는 순서를 정리한 문서.",
        "태그 (AI 추정) #결제 #위젯 #연동 #가이드",
        "묶음 결제조사",
        "본문 3,420자  펼치기",
        "→ 고르기 131 또는 묶음 <이름> 또는 고치기 131 또는 버리기 131",
      ]);
    });

    it("직접고친요약이고묶음이없을때_화면을그리면_직접고침이름표와묶음없음을보이는지", () => {
      // given
      const value = detail({ bundles: [] }, { summarySource: "user" });

      // when
      const shown = shownDetail(value);

      // then
      expect(shown).toContain("요약 (직접 고침) 결제위젯을 붙이는 순서를 정리한 문서.");
      expect(shown).toContain("묶음 없음");
    });

    it("자세히보기일때_태그를누르면_입력줄에찾기태그를찍는지", () => {
      // given
      const { onInputChange } = renderView({ lines: [{ kind: "itemDetail", detail: detail() }] });

      // when
      fireEvent.click(screen.getByRole("button", { name: "#위젯" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("찾기 #위젯");
    });

    it("자세히보기일때_묶음이름을누르면_입력줄에묶음이름을찍는지", () => {
      // given
      const { onInputChange } = renderView({ lines: [{ kind: "itemDetail", detail: detail() }] });

      // when
      fireEvent.click(screen.getByRole("button", { name: "결제조사" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("묶음 결제조사");
    });

    it("본문이접혀있을때_펼치기를누르면_입력줄을건드리지않고본문과접기를보이는지", () => {
      // given
      const { container, onInputChange } = renderView({ lines: [{ kind: "itemDetail", detail: detail() }] });

      // when
      fireEvent.click(screen.getByRole("button", { name: "펼치기" }));

      // then
      expect(container.querySelector(".gt-preview")!.textContent).toBe("결제위젯 본문");
      expect(screen.getByRole("button", { name: "접기" })).toBeTruthy();
      expect(onInputChange).not.toHaveBeenCalled();
    });

    it("글자료를열었을때_화면을그리면_출처는직접넣음글이고본문을펼쳐두는지", () => {
      // given
      const value = detail({ bodyLength: 12, body: "회의 메모 본문" }, { kind: "text", source: null });

      // when
      const { container } = renderView({ lines: [{ kind: "itemDetail", detail: value }] });

      // then
      expect(outputLines(container).map(shownLine)).toContain("출처 직접 넣음 · 글");
      expect(container.querySelector(".gt-preview")!.textContent).toBe("회의 메모 본문");
    });

    it("이미지자료를열었을때_화면을그리면_이미지에서읽음과미리보기와원본열기를보이는지", () => {
      // given
      const value = detail(
        {
          bodyLength: 214,
          bodyFromImage: true,
          originalUrl: "https://storage.example/original.png",
          previewUrl: "https://storage.example/preview.png",
        },
        { kind: "file", title: "파란컵 텀블러 캠페인 캡처.png", source: "png" },
      );

      // when
      const { container } = renderView({ lines: [{ kind: "itemDetail", detail: value }] });
      const shown = outputLines(container).map(shownLine);

      // then
      expect(shown).toContain("출처 직접 넣음 · 이미지");
      expect(shown).toContain("본문 (이미지에서 읽음) 214자  펼치기");
      expect(container.querySelector("img")!.getAttribute("src")).toBe("https://storage.example/preview.png");
      const original = screen.getByRole("link", { name: "원본 열기" });
      expect(original.getAttribute("href")).toBe("https://storage.example/original.png");
      expect(original.getAttribute("target")).toBe("_blank");
    });

    it("링크자료를열었을때_출처호스트를보면_원래주소를새탭으로여는링크인지", () => {
      // given
      // when
      renderView({ lines: [{ kind: "itemDetail", detail: detail() }] });

      // then
      const source = screen.getByRole("link", { name: "docs.tosspayments.com" });
      expect(source.getAttribute("href")).toBe("https://docs.tosspayments.com/guides/widget");
      expect(source.getAttribute("target")).toBe("_blank");
      expect(source.getAttribute("rel")).toBe("noopener noreferrer");
    });

    it("링크주소가웹주소가아닐때_화면을그리면_출처를링크로만들지않는지", () => {
      // given
      // when
      renderView({ lines: [{ kind: "itemDetail", detail: detail({ url: "javascript:alert(1)" }) }] });

      // then
      expect(screen.queryByRole("link", { name: "docs.tosspayments.com" })).toBeNull();
    });

    it("링크주소가없을때_화면을그리면_출처호스트를글자로만보이는지", () => {
      // given
      // when
      renderView({ lines: [{ kind: "itemDetail", detail: detail({ url: null }) }] });

      // then
      expect(screen.queryByRole("link", { name: "docs.tosspayments.com" })).toBeNull();
      expect(screen.getByText("docs.tosspayments.com")).toBeTruthy();
    });

    it("PDF자료를열었을때_화면을그리면_출처형식을대문자로보이는지", () => {
      // given
      const value = detail({ originalUrl: "https://storage.example/a.pdf" }, { kind: "file", title: "보고서.pdf", source: "pdf" });

      // when
      const shown = shownDetail(value);

      // then
      expect(shown).toContain("출처 직접 넣음 · PDF");
    });

    it("본문을못가져온자료를열었을때_화면을그리면_상태줄과본문없음이유를보이고요약줄을빼는지", () => {
      // given
      const value = detail(
        { handoffSummary: null, body: null, bodyLength: 0, allTags: [] },
        { status: "blocked", blockedReason: "loginRequired", summarySource: null },
      );

      // when
      const shown = shownDetail(value);

      // then
      expect(shown).toContain("상태 ! 본문 못 가져옴: 로그인 필요  제목·링크만 저장");
      expect(shown).toContain("· 본문 없음: 로그인 필요");
      expect(shown.some((text) => text.includes("요약"))).toBe(false);
      expect(shown.some((text) => text.startsWith("태그"))).toBe(false);
    });

    it("처리중인자료를열었을때_화면을그리면_상태에요약생성중을보이는지", () => {
      // given
      const value = detail({ handoffSummary: null, body: null, bodyLength: null }, { status: "processing", summarySource: null });

      // when
      const shown = shownDetail(value);

      // then
      expect(shown).toContain("상태 · 요약 생성 중");
      expect(shown.some((text) => text.includes("본문"))).toBe(false);
    });

    it("처리에실패해본문이없을때_화면을그리면_본문없음과처리실패를보이는지", () => {
      // given
      const value = detail({ handoffSummary: null, body: null, bodyLength: null }, { status: "failed", summarySource: null });

      // when
      const shown = shownDetail(value);

      // then
      expect(shown).toContain("· 본문 없음: 처리 실패");
    });

    it("처리가끝났는데본문이없을때_화면을그리면_본문줄을그리지않는지", () => {
      // given
      const value = detail({ body: null, bodyLength: null });

      // when
      const shown = shownDetail(value);

      // then
      expect(shown.some((text) => text.includes("본문"))).toBe(false);
    });

    it("자세히보기일때_다음명령칩을누르면_입력줄에그명령을찍기만하는지", () => {
      // given
      const { onInputChange, onSubmit } = renderView({ lines: [{ kind: "itemDetail", detail: detail() }] });

      // when
      fireEvent.click(screen.getByRole("button", { name: "고치기 131" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("고치기 131");
      expect(onSubmit).not.toHaveBeenCalled();
    });

    it("열기에번호를둘이상주었을때_화면을그리면_번호하나만과예를보이는지", () => {
      // given
      // when
      const shown = shownOutput([{ kind: "prompt", text: "열기 131 140" }, { kind: "oneNumberOnly", command: "peek" }]);

      // then
      expect(shown.slice(1)).toEqual(["✗ 번호 하나만  예: 열기 131"]);
    });

    it("열기에번호가없을때_화면을그리면_번호없음과예를보이는지", () => {
      // given
      // when
      const shown = shownOutput([{ kind: "prompt", text: "열기" }, { kind: "missingArgument", command: "peek" }]);

      // then
      expect(shown.slice(1)).toEqual(["✗ 번호 없음  예: 열기 131"]);
    });

    it("목록일때_제목을누르면_입력줄에열기번호를찍는지", () => {
      // given
      const { onInputChange } = renderView({
        lines: [{ kind: "recentList", items: [item({ number: 97, title: "PG사 수수료 비교 정리.pdf" })], hasMore: false }],
      });

      // when
      fireEvent.click(screen.getByRole("button", { name: "PG사 수수료 비교 정리.pdf" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("열기 97");
    });
  });

  describe("찾아두기(#134, ARC-012)", () => {
    function shownBlock(prompt: string, ...rest: TerminalLine[]): string[] {
      return shownOutput([{ kind: "prompt", text: prompt }, ...rest]).slice(1);
    }

    const QUERY = { text: "결제", words: "결제", tags: [] };

    it("새검색어를찾아뒀을때_화면을그리면_찾아둠건수와보관함안내를보이는지", () => {
      // given
      // when
      const shown = shownBlock("찾아두기 텀블러 캠페인", { kind: "searchSaved", query: "텀블러 캠페인", total: 4, already: false });

      // then
      expect(shown).toEqual(["✓ 찾아둠: 텀블러 캠페인  4건", "· 보관함 저장한 찾기에 있음"]);
    });

    it("0건인검색어를찾아뒀을때_화면을그리면_맞는자료가저장되면모임을보이는지", () => {
      // given
      // when
      const shown = shownBlock("찾아두기 겨울 굿즈", { kind: "searchSaved", query: "겨울 굿즈", total: 0, already: false });

      // then
      expect(shown).toEqual(["✓ 찾아둠: 겨울 굿즈  0건", "· 맞는 자료가 저장되면 모임"]);
    });

    it("이미찾아둔검색어일때_화면을그리면_이미찾아둠만보이는지", () => {
      // given
      // when
      const shown = shownBlock("찾아두기 텀블러 캠페인", { kind: "searchSaved", query: "텀블러 캠페인", total: 4, already: true });

      // then
      expect(shown).toEqual(["! 이미 찾아둠: 텀블러 캠페인"]);
    });

    it("찾아둔것이있을때_찾아두기를치면_개수머리와검색어별건수를보이는지", () => {
      // given
      const line: TerminalLine = {
        kind: "savedSearchList",
        searches: [
          { query: "겨울 굿즈", count: 0 },
          { query: "텀블러 캠페인", count: 4 },
        ],
      };

      // when
      const shown = shownBlock("찾아두기", line);

      // then
      expect(shown).toEqual(["2개 찾아둠", "겨울 굿즈 0건", "텀블러 캠페인 4건"]);
    });

    it("찾아둔목록일때_검색어를누르면_입력줄에찾아두기검색어를찍는지", () => {
      // given
      const { onInputChange } = renderView({ lines: [{ kind: "savedSearchList", searches: [{ query: "텀블러 캠페인", count: 4 }] }] });

      // when
      fireEvent.click(screen.getByRole("button", { name: "텀블러 캠페인" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("찾아두기 텀블러 캠페인");
    });

    it("찾아둔것이없을때_찾아두기를치면_없음과다음명령을보이는지", () => {
      // given
      // when
      const shown = shownBlock("찾아두기", { kind: "savedSearchList", searches: [] });

      // then
      expect(shown).toEqual(["· 찾아둔 것 없음", "→ 찾아두기 <검색어>"]);
    });

    it("찾아두기에검색어가없을때_화면을그리면_검색어없음과예를보이는지", () => {
      // given
      // when
      const shown = shownBlock("찾아두기 ", { kind: "missingArgument", command: "gather" });

      // then
      expect(shown).toEqual(["✗ 검색어 없음  예: 찾아두기 텀블러 캠페인"]);
    });

    it("시점이붙은검색어를찾아두려할때_화면을그리면_실패와시점없는명령을보이는지", () => {
      // given
      // when
      const shown = shownBlock("찾아두기 텀블러 3주전", { kind: "savedSearchPeriod", period: "3주전", suggestion: "찾아두기 텀블러" });

      // then
      expect(shown).toEqual(["✗ 시점은 찾아두지 않음: 3주전", "→ 찾아두기 텀블러"]);
    });

    it("검색어가너무길때_화면을그리면_40자초과를알리는지", () => {
      // given
      // when
      const shown = shownBlock("찾아두기 …", { kind: "savedSearchTooLong" });

      // then
      expect(shown).toEqual(["✗ 검색어 40자 초과"]);
    });

    it("찾아둔것을지우려할때_화면을그리면_자료는남음과실행낱말을묻는지", () => {
      // given
      // when
      const shown = shownBlock("찾아두기 텀블러 캠페인 지우기", { kind: "savedSearchDeleteConfirm", query: "텀블러 캠페인" });

      // then
      expect(shown).toEqual(["! 지우기? 찾아둔 텀블러 캠페인 (자료는 남음)", "→ 실행: 지우기 다시 입력 · 취소: 그 외 입력"]);
    });

    it("찾아둔것을지웠을때_화면을그리면_지움을보이는지", () => {
      // given
      // when
      const shown = shownBlock("지우기", { kind: "savedSearchDeleted", query: "텀블러 캠페인" });

      // then
      expect(shown).toEqual(["✓ 지움  찾아둔 텀블러 캠페인"]);
    });

    it("없는찾아둔것을지우려할때_화면을그리면_찾아둔것없음과검색어를보이는지", () => {
      // given
      // when
      const shown = shownBlock("찾아두기 텀블러 지우기", { kind: "savedSearchNotFound", query: "텀블러" });

      // then
      expect(shown).toEqual(["✗ 찾아둔 것 없음: 텀블러"]);
    });

    it("찾기결과일때_화면을그리면_맨아래에찾아두기검색어칩을두는지", () => {
      // given
      // when
      const shown = shownBlock("찾기 결제", { kind: "searchResult", query: QUERY, total: 1, items: [item()], hasMore: false });

      // then
      expect(shown[shown.length - 1]).toBe("→ 찾아두기 결제");
    });

    it("찾기결과일때_찾아두기칩을누르면_입력줄에찍기만하는지", () => {
      // given
      const { onInputChange, onSubmit } = renderView({
        lines: [{ kind: "searchResult", query: QUERY, total: 1, items: [item()], hasMore: false }],
      });

      // when
      fireEvent.click(screen.getByRole("button", { name: "찾아두기 결제" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("찾아두기 결제");
      expect(onSubmit).not.toHaveBeenCalled();
    });

    it("시점을붙인찾기결과일때_화면을그리면_찾아두기칩을두지않는지", () => {
      // given
      const period = { label: "지난주", from: "2026-11-16T15:00:00Z", to: "2026-11-23T15:00:00Z" };
      const line: TerminalLine = {
        kind: "searchResult",
        query: { text: "결제 지난주", words: "결제", tags: [] },
        total: 1,
        items: [item({ savedAt: "2026-11-18T03:00:00Z" })],
        hasMore: false,
        period,
      };

      // when
      const shown = shownBlock("찾기 결제 지난주", line);

      // then
      expect(shown.some((text) => text.includes("찾아두기"))).toBe(false);
    });

    it("이미찾아둔검색어의찾기결과일때_화면을그리면_찾아두기칩을두지않는지", () => {
      // given
      const line: TerminalLine = { kind: "searchResult", query: QUERY, total: 1, items: [item()], hasMore: false, isSavedSearch: true };

      // when
      const shown = shownBlock("찾기 결제", line);

      // then
      expect(shown.some((text) => text.startsWith("→ 찾아두기"))).toBe(false);
    });

    it("찾아둔뒤결과일때_화면을그리면_찾아두기칩을두지않는지", () => {
      // given
      // when
      const shown = shownBlock(
        "찾아두기 결제",
        { kind: "searchSaved", query: "결제", total: 1, already: false },
        { kind: "searchResult", query: QUERY, total: 1, items: [item()], hasMore: false },
      );

      // then
      expect(shown.some((text) => text.startsWith("→ 찾아두기"))).toBe(false);
    });
  });

  describe("가져오기(#127, commands 6절·user-flow 10절)", () => {
    function shownBlock(prompt: string, line: TerminalLine): string[] {
      return shownOutput([{ kind: "prompt", text: prompt }, line]).slice(1);
    }

    function finished(overrides: Partial<Extract<TerminalLine, { kind: "importFinished" }>> = {}): TerminalLine {
      return { kind: "importFinished", saved: 150, skipped: 25, failed: 0, overLimit: 0, failedUrls: [], ...overrides };
    }

    it("가져오기를쳤을때_화면을그리면_북마크파일끌어다놓기안내를보이는지", () => {
      // given
      // when
      const shown = shownBlock("가져오기", { kind: "importPrompt" });

      // then
      expect(shown).toEqual(["· 북마크 파일을 끌어다 놓기 (브라우저에서 내보낸 HTML, 한 번에 200건)"]);
    });

    it("가져오는중일때_화면을그리면_진행건수와계속됨안내를보이는지", () => {
      // given
      // when
      const shown = shownBlock("가져오기", { kind: "importProgress", done: 120, total: 180 });

      // then
      expect(shown).toEqual(["· 가져오는 중  120 / 180건", "  다른 명령을 쳐도 계속됨"]);
    });

    it("가져오기가끝났을때_화면을그리면_저장건너뜀실패건수를보이는지", () => {
      // given
      // when
      const shown = shownBlock("가져오기", finished());

      // then
      expect(shown).toEqual(["✓ 저장 150건 · 건너뜀 25건 (이미 저장됨) · 실패 0건"]);
    });

    it("실패한링크가있을때_화면을그리면_실패링크를줄마다보이는지", () => {
      // given
      const line = finished({ failed: 2, failedUrls: ["http://old-blog.example/post/12", "http://intra.example/wiki"] });

      // when
      const shown = shownBlock("가져오기", line);

      // then
      expect(shown.slice(1)).toEqual(["  실패: http://old-blog.example/post/12", "  실패: http://intra.example/wiki"]);
    });

    it("200건을넘은링크가있을때_화면을그리면_끝줄다음에안가져온건수와다시가져오기를보이는지", () => {
      // given
      // when
      const shown = shownBlock("가져오기", finished({ saved: 200, skipped: 0, overLimit: 312 }));

      // then
      expect(shown).toEqual([
        "✓ 저장 200건 · 건너뜀 0건 (이미 저장됨) · 실패 0건",
        "! 200건 넘어 안 가져옴 312건  → 나눠서 다시: 가져오기",
      ]);
    });

    it("200건을넘었을때_가져오기칩을누르면_입력줄에찍기만하는지", () => {
      // given
      const { onInputChange, onSubmit } = renderView({ lines: [finished({ overLimit: 3 })] });

      // when
      fireEvent.click(screen.getByRole("button", { name: "가져오기" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("가져오기");
      expect(onSubmit).not.toHaveBeenCalled();
    });
  });

  describe("AI 도구 연결(#124, ACC-002)", () => {
    const MCP_URL = "https://grep.example/mcp";
    const MCP_HELP = "  AI 도구의 연결(MCP) 설정에 이 주소를 넣고 그렙 계정으로 로그인. 연결한 도구는 검색·읽기만 가능";

    function shownBlock(prompt: string, line: TerminalLine): string[] {
      return shownOutput([{ kind: "prompt", text: prompt }, line]).slice(1);
    }

    it("연결이있을때_연결을치면_주소안내와연결수머리와연결마다한줄을보이는지", () => {
      // given
      const line: TerminalLine = {
        kind: "connectionList",
        mcpUrl: MCP_URL,
        connections: [
          { number: 1, client: "Claude", connectedAt: "2026-11-20T01:00:00Z", lastReadAt: "2026-11-26T01:00:00Z" },
          { number: 2, client: "Cursor", connectedAt: "2026-11-24T16:00:00Z", lastReadAt: null },
        ],
      };

      // when
      const shown = shownBlock("연결", line);

      // then
      expect(shown).toEqual([
        `· 연결 주소  ${MCP_URL}`,
        MCP_HELP,
        "2개 연결",
        "1 Claude 연결 11/20 읽음 11/26",
        "2 Cursor 연결 11/25",
        "→ 연결 끊기 <번호>",
      ]);
    });

    it("연결목록일때_연결끊기칩을누르면_입력줄에연결끊기와빈칸을찍는지", () => {
      // given
      const { onInputChange } = renderView({
        lines: [
          {
            kind: "connectionList",
            mcpUrl: MCP_URL,
            connections: [{ number: 1, client: "Claude", connectedAt: "2026-11-20T01:00:00Z", lastReadAt: null }],
          },
        ],
      });

      // when
      fireEvent.click(screen.getByRole("button", { name: "연결 끊기 <번호>" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("연결 끊기 ");
    });

    it("연결이없을때_연결을치면_주소안내와연결0개를보이는지", () => {
      // given
      // when
      const shown = shownBlock("연결", { kind: "connectionList", mcpUrl: MCP_URL, connections: [] });

      // then
      expect(shown).toEqual([`· 연결 주소  ${MCP_URL}`, MCP_HELP, "· 연결 0개"]);
    });

    it("연결을끊으려할때_화면을그리면_다시연결하려면처음부터와실행낱말을묻는지", () => {
      // given
      // when
      const shown = shownBlock("연결 끊기 2", { kind: "disconnectConfirm", number: 2, client: "Cursor" });

      // then
      expect(shown).toEqual(["! 끊기? Cursor (다시 연결하려면 처음부터)", "→ 실행: 끊기 다시 입력 · 취소: 그 외 입력"]);
    });

    it("연결을끊었을때_화면을그리면_끊김과도구이름을보이는지", () => {
      // given
      // when
      const shown = shownBlock("끊기", { kind: "disconnected", client: "Cursor", already: false });

      // then
      expect(shown).toEqual(["✓ 끊김  Cursor"]);
    });

    it("이미끊긴연결일때_화면을그리면_이미끊김을보이는지", () => {
      // given
      // when
      const shown = shownBlock("끊기", { kind: "disconnected", client: "Cursor", already: true });

      // then
      expect(shown).toEqual(["! 이미 끊김  Cursor"]);
    });

    it("없는연결번호일때_화면을그리면_없는연결과번호를보이는지", () => {
      // given
      // when
      const shown = shownBlock("연결 끊기 9", { kind: "connectionNotFound", number: 9 });

      // then
      expect(shown).toEqual(["✗ 없는 연결: 9"]);
    });

    it("로그인만료로연결이끝났을때_그렙을열면_연결끊김이유와연결칩을보이는지", () => {
      // given
      // when
      const shown = shownOutput([{ kind: "connectionEnded", client: "Claude", reason: "expired" }]);

      // then
      expect(shown).toEqual(["! 연결 끊김: Claude (로그인 만료)", "→ 연결"]);
    });

    it("다른기기에서끊은연결일때_그렙을열면_다른기기에서끊음을이유로보이는지", () => {
      // given
      // when
      const shown = shownOutput([{ kind: "connectionEnded", client: "Cursor", reason: "revoked" }]);

      // then
      expect(shown[0]).toBe("! 연결 끊김: Cursor (다른 기기에서 끊음)");
    });

    it("연결이있는데모든기기로그아웃을칠때_화면을그리면_AI도구연결수를보이는지", () => {
      // given
      // when
      const shown = shownBlock("로그아웃 모든기기", { kind: "signOutEverywhereConfirm", connectionCount: 2 });

      // then
      expect(shown[0]).toBe("! 로그아웃? 모든 기기 · AI 도구 연결 2개 (다른 기기는 최대 1시간 뒤)");
    });

    it("연결이없는데모든기기로그아웃을칠때_화면을그리면_연결수칸을빼는지", () => {
      // given
      // when
      const shown = shownBlock("로그아웃 모든기기", { kind: "signOutEverywhereConfirm", connectionCount: 0 });

      // then
      expect(shown[0]).toBe("! 로그아웃? 모든 기기 (다른 기기는 최대 1시간 뒤)");
    });
  });

  describe("폴더 안내(#137, ARC-007 규칙 11)", () => {
    it("폴더를만들려할때_화면을그리면_묶음이폴더역할이라는안내와명령칩을보이는지", () => {
      // given
      // when
      const shown = shownOutput([{ kind: "prompt", text: "mkdir 결제" }, { kind: "folderHint" }]);

      // then
      expect(shown.slice(1)).toEqual(["· 폴더 없음: 묶음이 폴더 역할  → 고르기 <번호> · 묶음 <이름>"]);
    });

    it("폴더안내일때_묶음칩을누르면_입력줄에묶음과빈칸을찍는지", () => {
      // given
      const { onInputChange } = renderView({ lines: [{ kind: "folderHint" }] });

      // when
      fireEvent.click(screen.getByRole("button", { name: "묶음 <이름>" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("묶음 ");
    });
  });
});
