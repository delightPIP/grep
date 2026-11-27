import { describe, expect, it } from "vitest";
import type { LoggedOutState } from "./view-state";

describe("view-state 계약", () => {
  it("처음로그인화면을만들때_기본상태를쓰면_알림없이버튼이열려있는지", () => {
    // given
    const initial: LoggedOutState = { notice: null, isSigningIn: false };

    // when
    const { notice, isSigningIn } = initial;

    // then
    expect(notice).toBeNull();
    expect(isSigningIn).toBe(false);
  });
});
