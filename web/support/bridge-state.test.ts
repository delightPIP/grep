import { describe, expect, it } from "vitest";
import { toLoggedInState, toLoggedOutState } from "./bridge-state";

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
    const rows = [
      { kind: "prompt", text: "찻기 결제" },
      { kind: "unknownCommand", text: "찻기" },
    ];

    // when
    const state = toLoggedInState(34, rows, "찾");

    // then
    expect(state).toEqual({
      itemCount: 34,
      lines: [
        { kind: "prompt", text: "찻기 결제" },
        { kind: "unknownCommand", name: "찻기" },
      ],
      input: "찾",
    });
  });

  it("자료수를아직못받았을때_터미널값을바꾸면_자료수가null로남는지", () => {
    // given
    const itemCount = null;

    // when
    const state = toLoggedInState(itemCount, [], "");

    // then
    expect(state.itemCount).toBeNull();
  });

  it("계약에없는줄종류일때_터미널값을바꾸면_오류를던지는지", () => {
    // given
    const rows = [{ kind: "saved", text: "x" }];

    // when
    const convert = () => toLoggedInState(0, rows, "");

    // then
    expect(convert).toThrow("saved");
  });
});
