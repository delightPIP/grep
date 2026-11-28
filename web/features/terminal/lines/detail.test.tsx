import { cleanup, fireEvent, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import type { ItemDetail, ItemSummary } from "../../../support/view-state";
import { renderView, shownLine, outputLines, shownOutput, item } from "../test-support";

afterEach(cleanup);

describe("LoggedInView", () => {
  describe("자세히 보기(#131, ARC-011)", () => {
    function detail(overrides: Partial<ItemDetail> = {}, itemOverrides: Partial<ItemSummary> = {}): ItemDetail {
      return {
        item: item({
          number: 131,
          title: "결제위젯 연동 가이드",
          source: "docs.tosspayments.com",
          status: "ready",
          summarySource: "ai",
          savedAt: "2026-11-26T05:03:00Z",
          ...itemOverrides,
        }),
        handoffSummary: "결제위젯을 붙이는 순서를 정리한 문서.",
        allTags: ["결제", "위젯", "연동", "가이드"],
        bundles: ["결제조사"],
        bodyLength: 3420,
        body: "결제위젯 본문",
        bodyFromImage: false,
        url: "https://docs.tosspayments.com/guides/widget",
        originalUrl: null,
        previewUrl: null,
        ...overrides,
      };
    }

    function shownDetail(value: ItemDetail): string[] {
      return shownOutput([{ kind: "prompt", text: `열기 ${value.item.number}` }, { kind: "itemDetail", detail: value }]).slice(1);
    }

    it("링크자료를열었을때_화면을그리면_정책차례대로머리출처저장요약태그묶음본문다음명령을보이는지", () => {
      // given
      // when
      const shown = shownDetail(detail());

      // then
      expect(shown).toEqual([
        "131 결제위젯 연동 가이드",
        "출처 docs.tosspayments.com",
        "저장 2026-11-26 14:03",
        "AI 요약 결제위젯을 붙이는 순서를 정리한 문서.",
        "태그 (AI 추정) #결제 #위젯 #연동 #가이드",
        "묶음 결제조사",
        "본문 3,420자  펼치기",
        "→ 고르기 131 또는 묶음 <이름> 또는 고치기 131 또는 버리기 131",
      ]);
    });

    it("직접고친요약이고묶음이없을때_화면을그리면_직접고침이름표와묶음없음을보이는지", () => {
      // given
      const value = detail({ bundles: [] }, { summarySource: "user" });

      // when
      const shown = shownDetail(value);

      // then
      expect(shown).toContain("요약 (직접 고침) 결제위젯을 붙이는 순서를 정리한 문서.");
      expect(shown).toContain("묶음 없음");
    });

    it("자세히보기일때_태그를누르면_입력줄에찾기태그를찍는지", () => {
      // given
      const { onInputChange } = renderView({ lines: [{ kind: "itemDetail", detail: detail() }] });

      // when
      fireEvent.click(screen.getByRole("button", { name: "#위젯" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("찾기 #위젯");
    });

    it("자세히보기일때_묶음이름을누르면_입력줄에묶음이름을찍는지", () => {
      // given
      const { onInputChange } = renderView({ lines: [{ kind: "itemDetail", detail: detail() }] });

      // when
      fireEvent.click(screen.getByRole("button", { name: "결제조사" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("묶음 결제조사");
    });

    it("본문이접혀있을때_펼치기를누르면_입력줄을건드리지않고본문과접기를보이는지", () => {
      // given
      const { container, onInputChange } = renderView({ lines: [{ kind: "itemDetail", detail: detail() }] });

      // when
      fireEvent.click(screen.getByRole("button", { name: "펼치기" }));

      // then
      expect(container.querySelector(".gt-preview")!.textContent).toBe("결제위젯 본문");
      expect(screen.getByRole("button", { name: "접기" })).toBeTruthy();
      expect(onInputChange).not.toHaveBeenCalled();
    });

    it("글자료를열었을때_화면을그리면_출처는직접넣음글이고본문을펼쳐두는지", () => {
      // given
      const value = detail({ bodyLength: 12, body: "회의 메모 본문" }, { kind: "text", source: null });

      // when
      const { container } = renderView({ lines: [{ kind: "itemDetail", detail: value }] });

      // then
      expect(outputLines(container).map(shownLine)).toContain("출처 직접 넣음 · 글");
      expect(container.querySelector(".gt-preview")!.textContent).toBe("회의 메모 본문");
    });

    it("이미지자료를열었을때_화면을그리면_이미지에서읽음과미리보기와원본열기를보이는지", () => {
      // given
      const value = detail(
        {
          bodyLength: 214,
          bodyFromImage: true,
          originalUrl: "https://storage.example/original.png",
          previewUrl: "https://storage.example/preview.png",
        },
        { kind: "file", title: "파란컵 텀블러 캠페인 캡처.png", source: "png" },
      );

      // when
      const { container } = renderView({ lines: [{ kind: "itemDetail", detail: value }] });
      const shown = outputLines(container).map(shownLine);

      // then
      expect(shown).toContain("출처 직접 넣음 · 이미지");
      expect(shown).toContain("본문 (이미지에서 읽음) 214자  펼치기");
      expect(container.querySelector("img")!.getAttribute("src")).toBe("https://storage.example/preview.png");
      const original = screen.getByRole("link", { name: "원본 열기" });
      expect(original.getAttribute("href")).toBe("https://storage.example/original.png");
      expect(original.getAttribute("target")).toBe("_blank");
    });

    it("링크자료를열었을때_출처호스트를보면_원래주소를새탭으로여는링크인지", () => {
      // given
      // when
      renderView({ lines: [{ kind: "itemDetail", detail: detail() }] });

      // then
      const source = screen.getByRole("link", { name: "docs.tosspayments.com" });
      expect(source.getAttribute("href")).toBe("https://docs.tosspayments.com/guides/widget");
      expect(source.getAttribute("target")).toBe("_blank");
      expect(source.getAttribute("rel")).toBe("noopener noreferrer");
    });

    it("링크주소가웹주소가아닐때_화면을그리면_출처를링크로만들지않는지", () => {
      // given
      // when
      renderView({ lines: [{ kind: "itemDetail", detail: detail({ url: "javascript:alert(1)" }) }] });

      // then
      expect(screen.queryByRole("link", { name: "docs.tosspayments.com" })).toBeNull();
    });

    it("링크주소가없을때_화면을그리면_출처호스트를글자로만보이는지", () => {
      // given
      // when
      renderView({ lines: [{ kind: "itemDetail", detail: detail({ url: null }) }] });

      // then
      expect(screen.queryByRole("link", { name: "docs.tosspayments.com" })).toBeNull();
      expect(screen.getByText("docs.tosspayments.com")).toBeTruthy();
    });

    it("PDF자료를열었을때_화면을그리면_출처형식을대문자로보이는지", () => {
      // given
      const value = detail({ originalUrl: "https://storage.example/a.pdf" }, { kind: "file", title: "보고서.pdf", source: "pdf" });

      // when
      const shown = shownDetail(value);

      // then
      expect(shown).toContain("출처 직접 넣음 · PDF");
    });

    it("본문을못가져온자료를열었을때_화면을그리면_상태줄과본문없음이유를보이고요약줄을빼는지", () => {
      // given
      const value = detail(
        { handoffSummary: null, body: null, bodyLength: 0, allTags: [] },
        { status: "blocked", blockedReason: "loginRequired", summarySource: null },
      );

      // when
      const shown = shownDetail(value);

      // then
      expect(shown).toContain("상태 ! 본문 못 가져옴: 로그인 필요  제목·링크만 저장");
      expect(shown).toContain("· 본문 없음: 로그인 필요");
      expect(shown.some((text) => text.includes("요약"))).toBe(false);
      expect(shown.some((text) => text.startsWith("태그"))).toBe(false);
    });

    it("처리중인자료를열었을때_화면을그리면_상태에요약생성중을보이는지", () => {
      // given
      const value = detail({ handoffSummary: null, body: null, bodyLength: null }, { status: "processing", summarySource: null });

      // when
      const shown = shownDetail(value);

      // then
      expect(shown).toContain("상태 · 요약 생성 중");
      expect(shown.some((text) => text.includes("본문"))).toBe(false);
    });

    it("처리에실패해본문이없을때_화면을그리면_본문없음과처리실패를보이는지", () => {
      // given
      const value = detail({ handoffSummary: null, body: null, bodyLength: null }, { status: "failed", summarySource: null });

      // when
      const shown = shownDetail(value);

      // then
      expect(shown).toContain("· 본문 없음: 처리 실패");
    });

    it("처리가끝났는데본문이없을때_화면을그리면_본문줄을그리지않는지", () => {
      // given
      const value = detail({ body: null, bodyLength: null });

      // when
      const shown = shownDetail(value);

      // then
      expect(shown.some((text) => text.includes("본문"))).toBe(false);
    });

    it("자세히보기일때_다음명령칩을누르면_입력줄에그명령을찍기만하는지", () => {
      // given
      const { onInputChange, onSubmit } = renderView({ lines: [{ kind: "itemDetail", detail: detail() }] });

      // when
      fireEvent.click(screen.getByRole("button", { name: "고치기 131" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("고치기 131");
      expect(onSubmit).not.toHaveBeenCalled();
    });

    it("열기에번호를둘이상주었을때_화면을그리면_번호하나만과예를보이는지", () => {
      // given
      // when
      const shown = shownOutput([{ kind: "prompt", text: "열기 131 140" }, { kind: "oneNumberOnly", command: "peek" }]);

      // then
      expect(shown.slice(1)).toEqual(["✗ 번호 하나만  예: 열기 131"]);
    });

    it("열기에번호가없을때_화면을그리면_번호없음과예를보이는지", () => {
      // given
      // when
      const shown = shownOutput([{ kind: "prompt", text: "열기" }, { kind: "missingArgument", command: "peek" }]);

      // then
      expect(shown.slice(1)).toEqual(["✗ 번호 없음  예: 열기 131"]);
    });

    it("목록일때_제목을누르면_입력줄에열기번호를찍는지", () => {
      // given
      const { onInputChange } = renderView({
        lines: [{ kind: "recentList", items: [item({ number: 97, title: "PG사 수수료 비교 정리.pdf", kind: "text" as const, source: null })], hasMore: false }],
      });

      // when
      fireEvent.click(screen.getByRole("button", { name: "PG사 수수료 비교 정리.pdf" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("열기 97");
    });
  });
});
