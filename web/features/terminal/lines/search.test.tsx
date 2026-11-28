import { cleanup, fireEvent, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import type { ItemSummary, LoggedInState, TerminalLine } from "../../../support/view-state";
import { renderView, shownLine, shownOutput, item } from "../test-support";

afterEach(cleanup);

describe("LoggedInView", () => {
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
      expect(shown.slice(1)).toEqual(["1건", "131 카페 텀블러 할인, 올겨울 캠페인 늘었다 2026-11-27 11:00", "요약 131", "→ 찾아두기 결제"]);
    });

    it("찾은자료가10건을넘을때_찾기결과를그리면_머리줄에전체중보인건수와더보기를보이는지", () => {
      // given
      const items = Array.from({ length: 10 }, (_, index) => ready(140 - index));

      // when
      const shown = shownOutput(found(23, items, true));

      // then
      expect(shown[1]).toBe("23건 중 10건");
      expect(shown.slice(-2)).toEqual(["→ 더 보기", "→ 찾아두기 결제"]);
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

  describe("시점을 붙인 찾기 0건(#114, commands 6절)", () => {
    const LAST_MONTH = { label: "지난달", from: "2026-09-30T15:00:00Z", to: "2026-10-31T15:00:00Z" };

    it("시점을붙인찾기가0건일때_화면을그리면_시점을밝히고기간없이다시찾기를권하는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        { kind: "prompt", text: "찾기 결제 #위젯 지난달" },
        {
          kind: "noResults",
          query: { text: "결제 #위젯 지난달", words: "결제", tags: ["위젯"] },
          recent: [],
          period: LAST_MONTH,
        },
      ];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown.slice(1)).toEqual(['· 0건: "결제 #위젯" (지난달)', "→ 기간 없이: 찾기 결제 #위젯"]);
    });

    it("시점이있는0건일때_기간없이칩을누르면_입력줄에찍기만하는지", () => {
      // given
      const { onInputChange } = renderView({
        lines: [{ kind: "noResults", query: { text: "결제 지난달", words: "결제", tags: [] }, recent: [], period: LAST_MONTH }],
      });

      // when
      fireEvent.click(screen.getByRole("button", { name: "찾기 결제" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("찾기 결제");
    });
  });

  describe("찾아두기(#134, ARC-012)", () => {
    function shownBlock(prompt: string, ...rest: TerminalLine[]): string[] {
      return shownOutput([{ kind: "prompt", text: prompt }, ...rest]).slice(1);
    }

    const QUERY = { text: "결제", words: "결제", tags: [] };

    it("새검색어를찾아뒀을때_화면을그리면_찾아둠건수와보관함안내를보이는지", () => {
      // given
      // when
      const shown = shownBlock("찾아두기 텀블러 캠페인", { kind: "searchSaved", query: "텀블러 캠페인", total: 4, already: false });

      // then
      expect(shown).toEqual(["✓ 찾아둠: 텀블러 캠페인  4건", "· 보관함 저장한 찾기에 있음"]);
    });

    it("0건인검색어를찾아뒀을때_화면을그리면_맞는자료가저장되면모임을보이는지", () => {
      // given
      // when
      const shown = shownBlock("찾아두기 겨울 굿즈", { kind: "searchSaved", query: "겨울 굿즈", total: 0, already: false });

      // then
      expect(shown).toEqual(["✓ 찾아둠: 겨울 굿즈  0건", "· 맞는 자료가 저장되면 모임"]);
    });

    it("이미찾아둔검색어일때_화면을그리면_이미찾아둠만보이는지", () => {
      // given
      // when
      const shown = shownBlock("찾아두기 텀블러 캠페인", { kind: "searchSaved", query: "텀블러 캠페인", total: 4, already: true });

      // then
      expect(shown).toEqual(["! 이미 찾아둠: 텀블러 캠페인"]);
    });

    it("찾아둔것이있을때_찾아두기를치면_개수머리와검색어별건수를보이는지", () => {
      // given
      const line: TerminalLine = {
        kind: "savedSearchList",
        searches: [
          { query: "겨울 굿즈", count: 0 },
          { query: "텀블러 캠페인", count: 4 },
        ],
      };

      // when
      const shown = shownBlock("찾아두기", line);

      // then
      expect(shown).toEqual(["2개 찾아둠", "겨울 굿즈 0건", "텀블러 캠페인 4건"]);
    });

    it("찾아둔목록일때_검색어를누르면_입력줄에찾아두기검색어를찍는지", () => {
      // given
      const { onInputChange } = renderView({ lines: [{ kind: "savedSearchList", searches: [{ query: "텀블러 캠페인", count: 4 }] }] });

      // when
      fireEvent.click(screen.getByRole("button", { name: "텀블러 캠페인" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("찾아두기 텀블러 캠페인");
    });

    it("찾아둔것이없을때_찾아두기를치면_없음과다음명령을보이는지", () => {
      // given
      // when
      const shown = shownBlock("찾아두기", { kind: "savedSearchList", searches: [] });

      // then
      expect(shown).toEqual(["· 찾아둔 것 없음", "→ 찾아두기 <검색어>"]);
    });

    it("찾아두기에검색어가없을때_화면을그리면_검색어없음과예를보이는지", () => {
      // given
      // when
      const shown = shownBlock("찾아두기 ", { kind: "missingArgument", command: "gather" });

      // then
      expect(shown).toEqual(["✗ 검색어 없음  예: 찾아두기 텀블러 캠페인"]);
    });

    it("시점이붙은검색어를찾아두려할때_화면을그리면_실패와시점없는명령을보이는지", () => {
      // given
      // when
      const shown = shownBlock("찾아두기 텀블러 3주전", { kind: "savedSearchPeriod", period: "3주전", suggestion: "찾아두기 텀블러" });

      // then
      expect(shown).toEqual(["✗ 시점은 찾아두지 않음: 3주전", "→ 찾아두기 텀블러"]);
    });

    it("검색어가너무길때_화면을그리면_40자초과를알리는지", () => {
      // given
      // when
      const shown = shownBlock("찾아두기 …", { kind: "savedSearchTooLong" });

      // then
      expect(shown).toEqual(["✗ 검색어 40자 초과"]);
    });

    it("찾아둔것을지우려할때_화면을그리면_자료는남음과실행낱말을묻는지", () => {
      // given
      // when
      const shown = shownBlock("찾아두기 텀블러 캠페인 지우기", { kind: "savedSearchDeleteConfirm", query: "텀블러 캠페인" });

      // then
      expect(shown).toEqual(["! 지우기? 찾아둔 텀블러 캠페인 (자료는 남음)", "→ 실행: 지우기 다시 입력 · 취소: 그 외 입력"]);
    });

    it("찾아둔것을지웠을때_화면을그리면_지움을보이는지", () => {
      // given
      // when
      const shown = shownBlock("지우기", { kind: "savedSearchDeleted", query: "텀블러 캠페인" });

      // then
      expect(shown).toEqual(["✓ 지움  찾아둔 텀블러 캠페인"]);
    });

    it("없는찾아둔것을지우려할때_화면을그리면_찾아둔것없음과검색어를보이는지", () => {
      // given
      // when
      const shown = shownBlock("찾아두기 텀블러 지우기", { kind: "savedSearchNotFound", query: "텀블러" });

      // then
      expect(shown).toEqual(["✗ 찾아둔 것 없음: 텀블러"]);
    });

    it("찾기결과일때_화면을그리면_맨아래에찾아두기검색어칩을두는지", () => {
      // given
      // when
      const shown = shownBlock("찾기 결제", { kind: "searchResult", query: QUERY, total: 1, items: [item()], hasMore: false });

      // then
      expect(shown[shown.length - 1]).toBe("→ 찾아두기 결제");
    });

    it("찾기결과일때_찾아두기칩을누르면_입력줄에찍기만하는지", () => {
      // given
      const { onInputChange, onSubmit } = renderView({
        lines: [{ kind: "searchResult", query: QUERY, total: 1, items: [item()], hasMore: false }],
      });

      // when
      fireEvent.click(screen.getByRole("button", { name: "찾아두기 결제" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("찾아두기 결제");
      expect(onSubmit).not.toHaveBeenCalled();
    });

    it("시점을붙인찾기결과일때_화면을그리면_찾아두기칩을두지않는지", () => {
      // given
      const period = { label: "지난주", from: "2026-11-16T15:00:00Z", to: "2026-11-23T15:00:00Z" };
      const line: TerminalLine = {
        kind: "searchResult",
        query: { text: "결제 지난주", words: "결제", tags: [] },
        total: 1,
        items: [item({ savedAt: "2026-11-18T03:00:00Z" })],
        hasMore: false,
        period,
      };

      // when
      const shown = shownBlock("찾기 결제 지난주", line);

      // then
      expect(shown.some((text) => text.includes("찾아두기"))).toBe(false);
    });

    it("이미찾아둔검색어의찾기결과일때_화면을그리면_찾아두기칩을두지않는지", () => {
      // given
      const line: TerminalLine = { kind: "searchResult", query: QUERY, total: 1, items: [item()], hasMore: false, isSavedSearch: true };

      // when
      const shown = shownBlock("찾기 결제", line);

      // then
      expect(shown.some((text) => text.startsWith("→ 찾아두기"))).toBe(false);
    });

    it("찾아둔뒤결과일때_화면을그리면_찾아두기칩을두지않는지", () => {
      // given
      // when
      const shown = shownBlock(
        "찾아두기 결제",
        { kind: "searchSaved", query: "결제", total: 1, already: false },
        { kind: "searchResult", query: QUERY, total: 1, items: [item()], hasMore: false },
      );

      // then
      expect(shown.some((text) => text.startsWith("→ 찾아두기"))).toBe(false);
    });
  });

  describe("뜻 찾기 0건(#128, ADR-BCK-016)", () => {
    const QUERY = { text: "텀블러 할인", words: "텀블러 할인", tags: [] };
    const RELATED = [
      item({ number: 30, title: "카페 텀블러 할인, 올겨울 캠페인 늘었다", status: "ready" }),
      item({ number: 28, title: "파란컵 텀블러 캠페인 캡처.png", status: "ready" }),
    ];
    const RECENT = [item({ number: 131, title: "결제위젯 연동 가이드", status: "ready" })];

    it("뜻결과가있을때_0건이면_뜻이가까운자료줄과목록만그리는지", () => {
      // given
      const line: TerminalLine = { kind: "noResults", query: QUERY, recent: RECENT, related: RELATED };

      // when
      const shown = shownOutput([{ kind: "prompt", text: "찾기 텀블러 할인" }, line]).slice(1);

      // then
      expect(shown.slice(0, 2)).toEqual(['· 0건: "텀블러 할인"', "· 뜻이 가까운 자료 2건 (낱말은 다름)"]);
      expect(shown.filter((text) => /^(30|28) /.test(text))).toHaveLength(2);
      expect(shown.some((text) => text.includes("최근 저장") || text.startsWith("131 "))).toBe(false);
    });

    it("뜻결과가없을때_0건이면_최근저장3건을그리는지", () => {
      // given
      const line: TerminalLine = { kind: "noResults", query: QUERY, recent: RECENT, related: [] };

      // when
      const shown = shownOutput([{ kind: "prompt", text: "찾기 텀블러 할인" }, line]).slice(1);

      // then
      expect(shown.slice(0, 2)).toEqual(['· 0건: "텀블러 할인"', "· 최근 저장 1건 (검색 결과 아님)"]);
      expect(shown.some((text) => text.includes("뜻이 가까운"))).toBe(false);
    });

    it("시점이붙은0건에뜻결과가있을때_화면을그리면_기간없이줄다음에뜻결과를그리는지", () => {
      // given
      const period = { label: "지난주", from: "2026-11-16T15:00:00Z", to: "2026-11-23T15:00:00Z" };
      const line: TerminalLine = {
        kind: "noResults",
        query: { text: "텀블러 할인 지난주", words: "텀블러 할인", tags: [] },
        recent: RECENT,
        period,
        related: RELATED,
      };

      // when
      const shown = shownOutput([line]);

      // then
      expect(shown.slice(0, 3)).toEqual([
        '· 0건: "텀블러 할인" (지난주)',
        "→ 기간 없이: 찾기 텀블러 할인",
        "· 뜻이 가까운 자료 2건 (낱말은 다름)",
      ]);
    });
  });
});
