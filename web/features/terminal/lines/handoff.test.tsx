import { cleanup, fireEvent, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import type { CommandFailure, ItemRef, LoggedInState } from "../../../support/view-state";
import { renderView, shownLine, outputLines, shownOutput, item, KEEP } from "../test-support";

afterEach(cleanup);

describe("LoggedInView", () => {
  describe("고르기와 칩·번호 누르기(#62, ARC-001·commands 6절)", () => {
    const PICK = { kind: "prompt", text: "고르기 131 97" } as const;
    const PICKED: ItemRef[] = [
      { number: 131, title: "결제위젯 연동 가이드", kind: "text", source: null },
      { number: 97, title: "PG사 수수료 비교 정리.pdf", kind: "file", source: "pdf" },
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
        "선택 2  글 131 · PDF 97",
      );
    });

    it("종류를아는자료를골랐을때_화면을그리면_선택줄에종류낱말과번호를보이는지", () => {
      // given
      const selection = [
        { number: 25, title: "보고서.pdf", kind: "file" as const, source: null },
        { number: 12, title: "회의 메모", kind: "text" as const, source: null },
        { number: 3, title: "결제 가이드", kind: "link" as const, source: "example.com" },
        { number: 9, title: "화면.png", kind: "file" as const, source: null },
      ];

      // when
      const { container } = renderView({ selection } as Partial<LoggedInState>);

      // then
      expect(container.querySelector(".gt-selection")!.textContent).toBe("선택 4  PDF 25 · 글 12 · example.com 3 · PNG 9");
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
      const { container } = renderView({ lines, selection: [{ number: 131, title: "t", kind: "text" as const, source: null }] });

      // then
      const numbers = Array.from(container.querySelectorAll(".gt-row-num"), (cell) => cell.textContent);
      expect(numbers).toEqual(["▸131", "130"]);
    });

    it("고른자료가목록에있을때_그번호를다시누르면_입력줄에고르기빼기번호를찍기만하는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        { kind: "prompt", text: "최근" },
        { kind: "recentList", items: [item({ number: 131 }), item({ number: 130 })], hasMore: false },
      ];
      const { onInputChange, onSubmit } = renderView({ lines, selection: [{ number: 131, title: "t", kind: "text" as const, source: null }] });

      // when
      fireEvent.click(screen.getByRole("button", { name: "131" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("고르기 빼기 131");
      expect(onSubmit).not.toHaveBeenCalled();
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
              { number: 131, title: "결제위젯 연동 가이드", kind: "text" as const, source: null },
              { number: 97, title: "PG사 수수료 비교 정리.pdf", kind: "text" as const, source: null },
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
        { kind: "unpicked", items: [{ number: 140, title: "환불 규정", kind: "text" as const, source: null }], remaining: 2 },
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
