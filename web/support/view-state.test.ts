import { describe, expect, it } from "vitest";
import type { LoggedOutState } from "./view-state";

describe("view-state 계약", () => {
  it("처음_로그인화면을_만들때_기본상태를_쓰면_알림없이_버튼이_열려있는지", () => {
    // given
    const initial: LoggedOutState = { notice: null, isSigningIn: false };

    // when
    const { notice, isSigningIn } = initial;

    // then
    expect(notice).toBeNull();
    expect(isSigningIn).toBe(false);
  });
});
