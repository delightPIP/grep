import { cleanup, fireEvent, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import type { ItemSummary, LoggedInState } from "../../../support/view-state";
import { renderView, shownOutput, item } from "../test-support";

afterEach(cleanup);

describe("LoggedInView", () => {
  describe("최근 목록(#60, commands 6절·ARC-002·ARC-004·ARC-005)", () => {
    const RECENT = { kind: "prompt", text: "최근" } as const;

    function recent(items: ItemSummary[], hasMore = false): LoggedInState["lines"] {
      return [RECENT, { kind: "recentList", items, hasMore }];
    }

    it("요약이끝난자료가있을때_최근목록을그리면_번호제목출처저장시각과흐린요약태그를두줄로보이는지", () => {
      // given
      const ready = item({ status: "ready", listSummary: "카페 3곳이 텀블러 할인을 늘렸다", tags: ["텀블러", "캠페인"] });

      // when
      const shown = shownOutput(recent([ready]));

      // then
      expect(shown.slice(1)).toEqual([
        "131 카페 텀블러 할인, 올겨울 캠페인 늘었다 팀 가상 기사 2026-11-27 11:00",
        "카페 3곳이 텀블러 할인을 늘렸다 #텀블러 #캠페인",
      ]);
    });

    it("태그가5개일때_최근목록을그리면_앞3개만보이는지", () => {
      // given
      const ready = item({ status: "ready", listSummary: "요약", tags: ["가", "나", "다", "라", "마"] });

      // when
      const shown = shownOutput(recent([ready]));

      // then
      expect(shown[2]).toBe("요약 #가 #나 #다");
    });

    it("저장시각이UTC로올때_최근목록을그리면_한국시간으로보이는지", () => {
      // given
      const late = item({ savedAt: "2026-11-26T15:30:00Z", source: null });

      // when
      const shown = shownOutput(recent([late]));

      // then
      expect(shown[1]).toBe("131 카페 텀블러 할인, 올겨울 캠페인 늘었다 2026-11-27 00:30");
    });

    it("처리중인자료가있을때_최근목록을그리면_요약자리에흐린요약생성중을보이는지", () => {
      // given
      const items = [item({ number: 132, status: "received" }), item({ status: "processing" })];

      // when
      const { container } = renderView({ lines: recent(items) });

      // then
      const subs = Array.from(container.querySelectorAll(".gt-row-sub"));
      expect(subs.map((sub) => sub.textContent)).toEqual(["· 요약 생성 중", "· 요약 생성 중"]);
      expect(subs.every((sub) => sub.classList.contains("gt-hint"))).toBe(true);
    });

    it("본문을못가져온자료가있을때_최근목록을그리면_알림과고치기번호를보이는지", () => {
      // given
      const blocked = item({ number: 64, status: "blocked", blockedReason: "loginRequired" });

      // when
      const shown = shownOutput(recent([blocked]));

      // then
      expect(shown[2]).toBe("! 본문 못 가져옴 → 고치기 64");
    });

    it("처리가실패한자료가있을때_최근목록을그리면_요약못만듦알림을보이는지", () => {
      // given
      const failed = item({ status: "failed" });

      // when
      const shown = shownOutput(recent([failed]));

      // then
      expect(shown[2]).toBe("! 요약 못 만듦  제목·출처만 넘김");
    });

    it("일부만읽은자료일때_최근목록을그리면_요약끝에일부만읽음을붙이는지", () => {
      // given
      const partial = item({ status: "ready", listSummary: "겨울 굿즈 예산", partialNote: "앞 20쪽만 읽음" });

      // when
      const shown = shownOutput(recent([partial]));

      // then
      expect(shown[2]).toBe("겨울 굿즈 예산 (앞 20쪽만 읽음)");
    });

    it("다음자료가더있을때_더보기를누르면_더보기를알리는지", () => {
      // given
      const { onMoreRequested } = renderView({ lines: recent([item()], true) });

      // when
      fireEvent.click(screen.getByRole("button", { name: "더 보기" }));

      // then
      expect(onMoreRequested).toHaveBeenCalledOnce();
    });

    it("다음자료가없을때_최근목록을그리면_더보기를보이지않는지", () => {
      // given
      // when
      renderView({ lines: recent([item()], false) });

      // then
      expect(screen.queryByRole("button", { name: "더 보기" })).toBeNull();
    });
  });

  describe("시점 머리 줄·주 구분선(#114, user-flow 5절 3번·commands 3절 시점)", () => {
    // 한국 시간 10/1 00:00 ~ 11/1 00:00(반열린 구간)
    const LAST_MONTH = { label: "지난달", from: "2026-09-30T15:00:00Z", to: "2026-10-31T15:00:00Z" };
    // 한국 시간 11/16(월) 00:00 ~ 11/23(월) 00:00
    const LAST_WEEK = { label: "지난주", from: "2026-11-15T15:00:00Z", to: "2026-11-22T15:00:00Z" };
    const savedOn = (number: number, savedAt: string) =>
      item({ number, title: `자료 ${number}`, source: null, savedAt, status: "ready", listSummary: null, tags: [] });

    it("최근에시점이붙고여러주에걸칠때_화면을그리면_건수머리와주마다구분선을보이는지", () => {
      // given
      const items = [
        savedOn(9, "2026-10-30T01:00:00Z"),
        savedOn(6, "2026-10-25T16:00:00Z"), // 한국 시간 10/26(월) 01:00
        savedOn(5, "2026-10-25T14:00:00Z"), // 한국 시간 10/25(일) 23:00
      ];
      const lines: LoggedInState["lines"] = [
        { kind: "prompt", text: "최근 지난달" },
        { kind: "recentList", items, hasMore: false, period: LAST_MONTH },
      ];

      // when
      const shown = shownOutput(lines).slice(1);

      // then
      expect(shown[0]).toBe("3건 · 지난달 (10/1~10/31)");
      expect(shown[1]).toBe("── 10/26~11/1 ──");
      expect(shown[2]).toMatch(/^9 자료 9 /);
      expect(shown[3]).toMatch(/^6 자료 6 /);
      expect(shown[4]).toBe("── 10/19~10/25 ──");
      expect(shown[5]).toMatch(/^5 자료 5 /);
    });

    it("시점이한주안일때_화면을그리면_구분선없이머리만보이는지", () => {
      // given
      const items = [savedOn(12, "2026-11-20T03:00:00Z"), savedOn(11, "2026-11-16T03:00:00Z")];

      // when
      const shown = shownOutput([{ kind: "recentList", items, hasMore: false, period: LAST_WEEK }]);

      // then
      expect(shown[0]).toBe("2건 · 지난주 (11/16~11/22)");
      expect(shown.some((line) => line.startsWith("──"))).toBe(false);
    });

    it("최근에시점이붙고10건을넘을때_화면을그리면_전체중보인건수를머리에보이는지", () => {
      // given
      const items = [savedOn(9, "2026-10-30T01:00:00Z")];

      // when
      const shown = shownOutput([{ kind: "recentList", items, hasMore: true, period: LAST_MONTH, total: 23 }]);

      // then
      expect(shown[0]).toBe("23건 중 1건 · 지난달 (10/1~10/31)");
    });

    it("찾기에시점이붙고다음쪽이남았을때_화면을그리면_전체중보인건수와시점을한머리에보이는지", () => {
      // given
      const items = [savedOn(9, "2026-10-30T01:00:00Z")];

      // when
      const shown = shownOutput([
        { kind: "searchResult", query: { text: "결제 지난달", words: "결제", tags: [] }, total: 23, items, hasMore: true, period: LAST_MONTH },
      ]);

      // then
      expect(shown[0]).toBe("23건 중 1건 · 지난달 (10/1~10/31)");
    });
  });
});
