import { cleanup, fireEvent, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import type { LoggedInState, TerminalLine } from "../../../support/view-state";
import { renderView, shownOutput } from "../test-support";

afterEach(cleanup);

describe("LoggedInView", () => {
  describe("가져오기(#127, commands 6절·user-flow 10절)", () => {
    function shownBlock(prompt: string, line: TerminalLine): string[] {
      return shownOutput([{ kind: "prompt", text: prompt }, line]).slice(1);
    }

    function finished(overrides: Partial<Extract<TerminalLine, { kind: "importFinished" }>> = {}): TerminalLine {
      return { kind: "importFinished", saved: 150, skipped: 25, failed: 0, overLimit: 0, failedUrls: [], ...overrides };
    }

    it("북마크파일을명령없이놓았을때_화면을그리면_받지않는형식다음에가져오기를제안하는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        { kind: "prompt", text: "담기 bookmarks.html" },
        {
          kind: "saveFailed",
          reason: { kind: "unsupportedFormat", fileExtension: "html" },
          recovery: { kind: "file", name: "bookmarks.html" },
        },
        { kind: "importSuggest", fileName: "bookmarks.html" },
      ];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown.slice(1)).toEqual(["✗ 저장 안 됨: 받지 않는 형식 (.html)", "→ 북마크 파일이면: 가져오기"]);
    });

    it("가져오기제안이있을때_가져오기칩을누르면_입력줄에가져오기를찍는지", () => {
      // given
      const { onInputChange } = renderView({ lines: [{ kind: "importSuggest", fileName: "bookmarks.html" }] });

      // when
      fireEvent.click(screen.getByRole("button", { name: "가져오기" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("가져오기");
    });

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
});
