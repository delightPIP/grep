import { act, cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { LoggedInState } from "../../support/view-state";
import { renderView, shownLine, outputLines, shownOutput } from "./test-support";
import { LoggedInView } from "../logged-in/view";

afterEach(cleanup);

describe("LoggedInView", () => {
  describe("출력과 입력줄 자리(실제 터미널처럼 함께 스크롤)", () => {
    it("화면을그렸을때_선택줄과땅굴과입력줄을보면_출력스크롤칸맨끝에있어함께스크롤되는지", () => {
      // given
      // when
      const { container } = renderView({
        lines: [{ kind: "prompt", text: "최근" }],
        selection: [{ number: 7, title: "자료 7", kind: "text", source: null }],
      });

      // then
      const log = screen.getByRole("log");
      const dock = container.querySelector(".gt-dock")!;
      expect(log.contains(container.querySelector(".gt-selection"))).toBe(true);
      expect(dock.contains(screen.getByRole("textbox", { name: "명령 입력" }))).toBe(true);
      expect(dock.contains(container.querySelector(".gt-burrow"))).toBe(true);
      expect(log.lastElementChild).toBe(dock);
    });

    it("출력이늘었을때_출력칸을보면_맨아래로내려가는지", () => {
      // given
      const props = {
        itemCount: null, input: "", selection: [], processingCount: 0, isOffline: false,
        onInputChange: vi.fn(), onSubmit: vi.fn(), onPaste: vi.fn(), onFilesDrop: vi.fn(), onMoreRequested: vi.fn(),
      };
      const { rerender } = render(<LoggedInView {...props} lines={[{ kind: "prompt", text: "최근" }]} />);
      const log = screen.getByRole("log");
      Object.defineProperty(log, "scrollHeight", { configurable: true, value: 900 });

      // when
      rerender(<LoggedInView {...props} lines={[{ kind: "prompt", text: "최근" }, { kind: "prompt", text: "도움말" }]} />);

      // then
      expect(log.scrollTop).toBe(900);
    });
  });

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
      fireEvent.dragEnter(container.querySelector(".gt-terminal")!, filesDrag());

      // then
      expect(screen.getByText("놓으면 저장")).toBeTruthy();
      expect(screen.getByText("링크 · 글 · 이미지 · PDF · md · docx")).toBeTruthy();
    });

    it("파일을끌어온뒤_놓으면_파일들을알리고안내를닫는지", () => {
      // given
      const { container, onFilesDrop } = renderView();
      const screenElement = container.querySelector(".gt-terminal")!;
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
      const screenElement = container.querySelector(".gt-terminal")!;
      fireEvent.dragEnter(screenElement, filesDrag());

      // when
      fireEvent.dragLeave(screenElement, { relatedTarget: null });

      // then
      expect(screen.queryByText("놓으면 저장")).toBeNull();
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

  describe("땅굴 두더지(#175, 디자인 시스템 9절·시안 07·08)", () => {
    beforeEach(() => {
      vi.useFakeTimers();
    });

    afterEach(() => {
      vi.useRealTimers();
    });

    function wait(ms: number) {
      act(() => {
        vi.advanceTimersByTime(ms);
      });
    }

    function renderWithMole(mole: LoggedInState["mole"]) {
      const props = {
        itemCount: 3,
        lines: [],
        input: "",
        selection: [],
        processingCount: 0,
        isOffline: false,
        onInputChange: vi.fn(),
        onSubmit: vi.fn(),
        onPaste: vi.fn(),
        onFilesDrop: vi.fn(),
      };
      const view = render(<LoggedInView {...props} mole={mole} />);
      return {
        container: view.container,
        update: (next: LoggedInState["mole"], input = "") =>
          view.rerender(<LoggedInView {...props} input={input} mole={next} />),
      };
    }

    const moleButton = () => screen.getByRole("button", { name: "두더지 누르기" });

    it("화면을_그렸을때_땅굴이_입력줄_바로_위에_붙는지", () => {
      // given
      const { container } = renderWithMole(null);

      // when
      const dock = container.querySelector(".gt-dock");

      // then
      expect(dock?.firstElementChild?.classList.contains("gt-burrow")).toBe(true);
      expect(dock?.lastElementChild?.classList.contains("gt-dock-line")).toBe(true);
    });

    it("코어가_저장을_넘겼을때_잠시_뒤면_떨어지는_문서를_받는지", () => {
      // given
      const { container, update } = renderWithMole(null);

      // when
      update({ action: "save", seq: 1 });
      wait(520);

      // then
      expect(container.querySelector(".gt-burrow-doc.gt-fall")).not.toBeNull();
    });

    it("같은_동작이_새_순번으로_왔을때_다시_하고_순번이_그대로면_다시_하지_않는지", () => {
      // given
      const { update } = renderWithMole({ action: "error", seq: 1 });
      wait(800);

      // when
      update({ action: "error", seq: 1 }, "찾");
      wait(0);

      // then
      expect(moleButton().classList.contains("is-shake")).toBe(false);
      update({ action: "error", seq: 2 }, "찾");
      wait(0);
      expect(moleButton().classList.contains("is-shake")).toBe(true);
    });

    it("파일을_끌어_오는_동안이면_가운데서_만세하고_떠나면_그치는지", () => {
      // given
      const { container } = renderWithMole(null);
      const screenElement = container.querySelector(".gt-terminal")!;

      // when
      fireEvent.dragEnter(screenElement, { dataTransfer: { types: ["Files"], files: [] } });
      wait(320);

      // then
      expect(moleButton().classList.contains("is-cheer")).toBe(true);
      expect(moleButton().style.left).toBe("50%");
      fireEvent.dragLeave(screenElement, { relatedTarget: null });
      wait(0);
      expect(moleButton().classList.contains("is-cheer")).toBe(false);
    });
  });
});
