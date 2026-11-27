import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { CommandFailure, ItemSummary, LoggedInState } from "../../support/view-state";
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

    it("도움말을쳤을때_화면을그리면_안내줄과명령16줄과예시줄을보이는지", () => {
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
});
