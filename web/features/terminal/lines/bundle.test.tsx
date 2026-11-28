import { cleanup, fireEvent, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import type { TerminalLine } from "../../../support/view-state";
import { renderView, shownOutput, item } from "../test-support";

afterEach(cleanup);

describe("LoggedInView", () => {
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
          items: [{ number: 30, title: "카페 텀블러 할인", kind: "text" as const, source: null }],
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
      const { onInputChange } = renderView({ lines: [{ kind: "picked", items: [{ number: 131, title: "결제위젯 연동 가이드", kind: "text" as const, source: null }] }] });

      // when
      fireEvent.click(screen.getByRole("button", { name: "묶음 <이름>" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("묶음 ");
    });
  });
});
