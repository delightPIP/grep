import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { LoggedInState } from "../../support/view-state";
import { renderView, shownLine, outputLines, shownOutput, item } from "./test-support";
import { LoggedInView } from "../logged-in/view";

afterEach(cleanup);

describe("LoggedInView", () => {
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
});
