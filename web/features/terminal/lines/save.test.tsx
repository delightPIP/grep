import { cleanup } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import type { LoggedInState } from "../../../support/view-state";
import { shownOutput, item, KEEP } from "../test-support";

afterEach(cleanup);

describe("LoggedInView", () => {
  describe("저장 줄(#57, ARC-005·COM-001·COM-004)", () => {
    it("링크를저장했을때_화면을그리면_제목과출처뒤에요약생성중을보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [KEEP, { kind: "saved", item: item() }];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown.slice(1)).toEqual([
        "✓ 저장됨  카페 텀블러 할인, 올겨울 캠페인 늘었다 (팀 가상 기사)",
        "· 요약 생성 중",
      ]);
    });

    it("글을저장했을때_화면을그리면_글표시와첫줄24자까지만보이는지", () => {
      // given
      const title = "텀블러 세척 메모 베이킹소다 한 숟갈 넣고 하룻밤 두기\n둘째 줄";
      const lines: LoggedInState["lines"] = [KEEP, { kind: "saved", item: item({ kind: "text", title, source: null }) }];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown[1]).toBe("✓ 저장됨 (글)  텀블러 세척 메모 베이킹소다 한 숟갈 넣고");
    });

    it("요약이끝난자료를저장했을때_화면을그리면_요약생성중을보이지않는지", () => {
      // given
      const lines: LoggedInState["lines"] = [KEEP, { kind: "saved", item: item({ status: "ready" }) }];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown).not.toContain("· 요약 생성 중");
    });

    it("이미저장된링크일때_화면을그리면_기존번호와그자료목록행과고르기안내를보이는지", () => {
      // given
      const saved = item({ status: "ready", listSummary: "카페 3곳이 텀블러 할인을 늘렸다", tags: ["텀블러"] });
      const lines: LoggedInState["lines"] = [KEEP, { kind: "alreadySaved", item: saved }];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown.slice(1)).toEqual([
        "! 이미 저장됨 → 131번 (새로 만들지 않음)",
        "131 카페 텀블러 할인, 올겨울 캠페인 늘었다 팀 가상 기사 2026-11-27 11:00",
        "카페 3곳이 텀블러 할인을 늘렸다 #텀블러",
        "→ 고르기 131",
      ]);
    });

    it("휴지통자료와같을때_화면을그리면_되살리기안내를보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [KEEP, { kind: "inTrash", number: 57 }];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown[1]).toBe("! 휴지통에 있음 → 57번. 되살리기 57");
    });

    it.each([
      [{ kind: "disconnected" }, "연결 끊김"],
      [{ kind: "timedOut" }, "응답 없음"],
      [{ kind: "serverError" }, "서버 오류"],
    ] as const)("입력줄에되돌린저장이실패했을때_이유가%o이면_이유와입력은남겨둠을보이는지", (reason, word) => {
      // given
      const lines: LoggedInState["lines"] = [KEEP, { kind: "saveFailed", reason, recovery: { kind: "inputKept" } }];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown[1]).toBe(`✗ 저장 안 됨: ${word}  입력은 남겨 둠`);
    });

    it("새글을친뒤저장이실패했을때_화면을그리면_다시칠명령을다음줄에보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        KEEP,
        {
          kind: "saveFailed",
          reason: { kind: "timedOut" },
          recovery: { kind: "retry", command: "담기 https://example.com/a" },
        },
      ];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown.slice(1)).toEqual(["✗ 저장 안 됨: 응답 없음", "→ 다시: 담기 https://example.com/a"]);
    });

    it("놓은파일이연결끊김으로실패했을때_화면을그리면_파일이름을붙이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        { kind: "prompt", text: "담기 예산안.pdf" },
        { kind: "saveFailed", reason: { kind: "disconnected" }, recovery: { kind: "file", name: "예산안.pdf" } },
      ];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown[1]).toBe("✗ 저장 안 됨: 연결 끊김 (예산안.pdf)");
    });

    it("놓은파일이20MB를넘었을때_화면을그리면_COM004문구로이름과크기를보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        { kind: "prompt", text: "담기 영상.mov" },
        {
          kind: "saveFailed",
          reason: { kind: "tooLarge", fileName: "영상.mov", bytes: 31_457_280 },
          recovery: { kind: "file", name: "영상.mov" },
        },
      ];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown[1]).toBe("✗ 저장 안 됨: 20MB 넘음 (영상.mov · 30MB)");
    });

    it("놓은파일이받지않는형식일때_화면을그리면_COM004문구로확장자를보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        { kind: "prompt", text: "담기 자료.zip" },
        {
          kind: "saveFailed",
          reason: { kind: "unsupportedFormat", fileExtension: "zip" },
          recovery: { kind: "file", name: "자료.zip" },
        },
      ];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown[1]).toBe("✗ 저장 안 됨: 받지 않는 형식 (.zip)");
    });

    it("담기만쳤을때_화면을그리면_저장할것없음과예시를보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        { kind: "prompt", text: "담기" },
        { kind: "missingArgument", command: "keep" },
      ];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown[1]).toBe("✗ 저장할 것 없음  예: 담기 https://…");
    });

    it("찾기만쳤을때_화면을그리면_검색어없음과예시를보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [
        { kind: "prompt", text: "찾기" },
        { kind: "missingArgument", command: "seek" },
      ];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown[1]).toBe("✗ 검색어 없음  예: 찾기 결제");
    });

    it("태그이름없이샵만쳤을때_화면을그리면_태그없음과예시를보이는지", () => {
      // given
      const lines: LoggedInState["lines"] = [{ kind: "prompt", text: "찾기 #" }, { kind: "missingTag" }];

      // when
      const shown = shownOutput(lines);

      // then
      expect(shown[1]).toBe("✗ 태그 없음  예: 찾기 #결제");
    });
  });
});
