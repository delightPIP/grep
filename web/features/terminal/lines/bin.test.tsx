import { cleanup, fireEvent, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import type { ItemSummary, LoggedInState } from "../../../support/view-state";
import { renderView, shownOutput, item } from "../test-support";

afterEach(cleanup);

describe("LoggedInView", () => {
  describe("버리기·되살리기 결과(#93, ARC-008)", () => {
    it("1건을버렸을때_화면을그리면_휴지통건수와되살리기번호를보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        { kind: "prompt", text: "버리기 131" },
        { kind: "dropped", items: [{ number: 131, title: "결제 오류 정리", kind: "text" as const, source: null }] },
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
            { number: 131, title: "결제 오류 정리", kind: "text" as const, source: null },
            { number: 57, title: "환불 규정", kind: "text" as const, source: null },
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
            { number: 131, title: "결제 오류 정리", kind: "text" as const, source: null },
            { number: 57, title: "환불 규정", kind: "text" as const, source: null },
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
});
