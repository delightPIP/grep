import { describe, expect, it } from "vitest";
import { type BridgedLoggedInState, toLoggedInState, toLoggedOutState } from "./bridge-state";

describe("브리지 값을 뷰 상태로 바꾸기", () => {
  it("알림이없을때_로그인화면값을바꾸면_알림없는상태가되는지", () => {
    // given
    const noticeKind = null;

    // when
    const state = toLoggedOutState(noticeKind, null, true);

    // then
    expect(state).toEqual({ notice: null, isSigningIn: true });
  });

  it.each(["cancelled", "expired", "signedOut"] as const)(
    "알림종류가_%s일때_로그인화면_값을_바꾸면_같은_종류의_알림이_되는지",
    (kind) => {
      // given
      const failureReason = null;

      // when
      const state = toLoggedOutState(kind, failureReason, false);

      // then
      expect(state).toEqual({ notice: { kind }, isSigningIn: false });
    },
  );

  it("알림종류가failed일때_로그인화면값을바꾸면_이유가함께들어가는지", () => {
    // given
    const failureReason = "timedOut";

    // when
    const state = toLoggedOutState("failed", failureReason, false);

    // then
    expect(state.notice).toEqual({ kind: "failed", reason: "timedOut" });
  });

  it("계약에없는알림종류일때_로그인화면값을바꾸면_오류를던지는지", () => {
    // given
    const unknownKind = "banned";

    // when
    const convert = () => toLoggedOutState(unknownKind, null, false);

    // then
    expect(convert).toThrow("banned");
  });

  it("실패알림에이유가없을때_로그인화면값을바꾸면_오류를던지는지", () => {
    // given
    const failureReason = null;

    // when
    const convert = () => toLoggedOutState("failed", failureReason, false);

    // then
    expect(convert).toThrow("failed");
  });

  it("출력줄이섞여있을때_터미널값을바꾸면_종류별줄로순서대로바뀌는지", () => {
    // given
    const bridged = terminal({
      itemCount: 34,
      lines: [
        { kind: "prompt", text: "찻기 결제" },
        { kind: "unknownCommand", name: "찻기" },
      ],
      input: "찾",
    });

    // when
    const state = toLoggedInState(bridged);

    // then
    expect(state.itemCount).toBe(34);
    expect(state.lines).toEqual([
      { kind: "prompt", text: "찻기 결제" },
      { kind: "unknownCommand", name: "찻기" },
    ]);
    expect(state.input).toBe("찾");
  });

  it("값이든줄일때_터미널값을바꾸면_자료값이그대로남는지", () => {
    // given
    const item = {
      number: 30,
      kind: "link",
      title: "결제 연동 가이드",
      source: "docs.example.com",
      status: "processing",
      blockedReason: null,
      listSummary: null,
      summarySource: null,
      partialNote: null,
      tags: [],
      matchedIn: null,
      savedAt: "2026-11-27T03:00:00Z",
    };
    const bridged = terminal({ lines: [{ kind: "alreadySaved", item }] });

    // when
    const state = toLoggedInState(bridged);

    // then
    expect(state.lines).toEqual([{ kind: "alreadySaved", item }]);
  });

  it("고른자료와상태줄값이있을때_터미널값을바꾸면_선택과처리중수와연결상태가들어가는지", () => {
    // given
    const bridged = terminal({
      selection: [{ number: 131, title: "결제 연동 가이드" }],
      processingCount: 2,
      isOffline: true,
    });

    // when
    const state = toLoggedInState(bridged);

    // then
    expect(state.selection).toEqual([{ number: 131, title: "결제 연동 가이드" }]);
    expect(state.processingCount).toBe(2);
    expect(state.isOffline).toBe(true);
  });

  it("자료수를아직못받았을때_터미널값을바꾸면_자료수가null로남는지", () => {
    // given
    const bridged = terminal({ itemCount: null });

    // when
    const state = toLoggedInState(bridged);

    // then
    expect(state.itemCount).toBeNull();
  });

  it("계약에없는줄종류일때_터미널값을바꾸면_오류를던지는지", () => {
    // given
    const bridged = terminal({ lines: [{ kind: "deleted" }] });

    // when
    const convert = () => toLoggedInState(bridged);

    // then
    expect(convert).toThrow("deleted");
  });
});

function terminal(overrides: Partial<BridgedLoggedInState>): BridgedLoggedInState {
  return { itemCount: 0, lines: [], input: "", selection: [], processingCount: 0, isOffline: false, ...overrides };
}
