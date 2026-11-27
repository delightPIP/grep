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
    />,
  );
  return {
    onInputChange,
    onSubmit,
    onPaste,
    onFilesDrop,
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

    it("이미저장된링크일때_화면을그리면_기존번호와그자료한줄과고르기안내를보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [KEEP, { kind: "alreadySaved", item: item() }];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown.slice(1)).toEqual([
        "! 이미 저장됨 → 131번 (새로 만들지 않음)",
        "131  카페 텀블러 할인, 올겨울 캠페인 늘었다 (팀 가상 기사)",
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
});
