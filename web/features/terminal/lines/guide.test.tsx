import { cleanup, fireEvent, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import type { LoggedInState } from "../../../support/view-state";
import { renderView, headLines, shownOutput, item } from "../test-support";

afterEach(cleanup);

describe("LoggedInView", () => {
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
