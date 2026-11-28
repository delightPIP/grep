import { cleanup, fireEvent, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import type { TerminalLine } from "../../../support/view-state";
import { renderView, shownOutput } from "../test-support";

afterEach(cleanup);

describe("LoggedInView", () => {
  describe("AI 도구 연결(#124, ACC-002)", () => {
    const MCP_URL = "https://grep.example/mcp";
    const MCP_HELP = "  AI 도구의 연결(MCP) 설정에 이 주소를 넣고 그렙 계정으로 로그인. 연결한 도구는 검색·읽기만 가능";

    function shownBlock(prompt: string, line: TerminalLine): string[] {
      return shownOutput([{ kind: "prompt", text: prompt }, line]).slice(1);
    }

    it("연결이있을때_연결을치면_주소안내와연결수머리와연결마다한줄을보이는지", () => {
      // given
      const line: TerminalLine = {
        kind: "connectionList",
        mcpUrl: MCP_URL,
        connections: [
          { number: 1, client: "Claude", connectedAt: "2026-11-20T01:00:00Z", lastReadAt: "2026-11-26T01:00:00Z" },
          { number: 2, client: "Cursor", connectedAt: "2026-11-24T16:00:00Z", lastReadAt: null },
        ],
      };

      // when
      const shown = shownBlock("연결", line);

      // then
      expect(shown).toEqual([
        `· 연결 주소  ${MCP_URL}`,
        MCP_HELP,
        "2개 연결",
        "1 Claude 연결 11/20 읽음 11/26",
        "2 Cursor 연결 11/25",
        "→ 연결 끊기 <번호>",
      ]);
    });

    it("연결목록일때_연결끊기칩을누르면_입력줄에연결끊기와빈칸을찍는지", () => {
      // given
      const { onInputChange } = renderView({
        lines: [
          {
            kind: "connectionList",
            mcpUrl: MCP_URL,
            connections: [{ number: 1, client: "Claude", connectedAt: "2026-11-20T01:00:00Z", lastReadAt: null }],
          },
        ],
      });

      // when
      fireEvent.click(screen.getByRole("button", { name: "연결 끊기 <번호>" }));

      // then
      expect(onInputChange).toHaveBeenCalledWith("연결 끊기 ");
    });

    it("연결이없을때_연결을치면_주소안내와연결0개를보이는지", () => {
      // given
      // when
      const shown = shownBlock("연결", { kind: "connectionList", mcpUrl: MCP_URL, connections: [] });

      // then
      expect(shown).toEqual([`· 연결 주소  ${MCP_URL}`, MCP_HELP, "· 연결 0개"]);
    });

    it("연결을끊으려할때_화면을그리면_다시연결하려면처음부터와실행낱말을묻는지", () => {
      // given
      // when
      const shown = shownBlock("연결 끊기 2", { kind: "disconnectConfirm", number: 2, client: "Cursor" });

      // then
      expect(shown).toEqual(["! 끊기? Cursor (다시 연결하려면 처음부터)", "→ 실행: 끊기 다시 입력 · 취소: 그 외 입력"]);
    });

    it("연결을끊었을때_화면을그리면_끊김과도구이름을보이는지", () => {
      // given
      // when
      const shown = shownBlock("끊기", { kind: "disconnected", client: "Cursor", already: false });

      // then
      expect(shown).toEqual(["✓ 끊김  Cursor"]);
    });

    it("이미끊긴연결일때_화면을그리면_이미끊김을보이는지", () => {
      // given
      // when
      const shown = shownBlock("끊기", { kind: "disconnected", client: "Cursor", already: true });

      // then
      expect(shown).toEqual(["! 이미 끊김  Cursor"]);
    });

    it("없는연결번호일때_화면을그리면_없는연결과번호를보이는지", () => {
      // given
      // when
      const shown = shownBlock("연결 끊기 9", { kind: "connectionNotFound", number: 9 });

      // then
      expect(shown).toEqual(["✗ 없는 연결: 9"]);
    });

    it("로그인만료로연결이끝났을때_그렙을열면_연결끊김이유와연결칩을보이는지", () => {
      // given
      // when
      const shown = shownOutput([{ kind: "connectionEnded", client: "Claude", reason: "expired" }]);

      // then
      expect(shown).toEqual(["! 연결 끊김: Claude (로그인 만료)", "→ 연결"]);
    });

    it("다른기기에서끊은연결일때_그렙을열면_다른기기에서끊음을이유로보이는지", () => {
      // given
      // when
      const shown = shownOutput([{ kind: "connectionEnded", client: "Cursor", reason: "revoked" }]);

      // then
      expect(shown[0]).toBe("! 연결 끊김: Cursor (다른 기기에서 끊음)");
    });

    it("연결이있는데모든기기로그아웃을칠때_화면을그리면_AI도구연결수를보이는지", () => {
      // given
      // when
      const shown = shownBlock("로그아웃 모든기기", { kind: "signOutEverywhereConfirm", connectionCount: 2 });

      // then
      expect(shown[0]).toBe("! 로그아웃? 모든 기기 · AI 도구 연결 2개 (다른 기기는 최대 1시간 뒤)");
    });

    it("연결이없는데모든기기로그아웃을칠때_화면을그리면_연결수칸을빼는지", () => {
      // given
      // when
      const shown = shownBlock("로그아웃 모든기기", { kind: "signOutEverywhereConfirm", connectionCount: 0 });

      // then
      expect(shown[0]).toBe("! 로그아웃? 모든 기기 (다른 기기는 최대 1시간 뒤)");
    });
  });
});
