import { cleanup, fireEvent, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import type { LoggedInState } from "../../../support/view-state";
import { renderView, shownOutput } from "../test-support";

afterEach(cleanup);

describe("LoggedInView", () => {
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
});
