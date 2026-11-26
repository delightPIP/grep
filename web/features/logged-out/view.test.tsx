import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { LoggedOutNotice, LoggedOutState } from "../../support/view-state";
import { LoggedOutView } from "./view";

afterEach(cleanup);

function renderView(state: Partial<LoggedOutState> = {}) {
  const onSignIn = vi.fn();
  const { container } = render(
    <LoggedOutView notice={null} isSigningIn={false} {...state} onSignIn={onSignIn} />,
  );
  return { onSignIn, container };
}

function button(name: string): HTMLButtonElement {
  return screen.getByRole("button", { name }) as HTMLButtonElement;
}

/** 기호와 글을 CSS 간격으로 띄워 그리므로, 자식 칸을 한 칸 띄어 이어 붙여 화면에 보이는 줄로 만든다. */
function shownLine(element: Element): string {
  return Array.from(element.children, (child) => child.textContent).join(" ");
}

describe("LoggedOutView", () => {
  it("로그인하지않았을때_화면을그리면_로그인창에로그인필요줄과두버튼을보여주는지", () => {
    // given
    // when
    const { container } = renderView();

    // then
    expect(container.querySelector(".gt-titlebar-name")?.textContent).toBe("그렙 — 로그인");
    expect(shownLine(container.querySelector(".gt-login-prompt")!)).toBe("그렙 ~ $ 로그인 필요");
    expect(button("Google로 계속").disabled).toBe(false);
    expect(button("GitHub로 계속").disabled).toBe(false);
  });

  it("로그인하지않았을때_화면을그리면_시안의소개문장과표어를보여주는지", () => {
    // given
    // when
    renderView();

    // then
    expect(screen.getByText("저장해 둔 링크·캡처·PDF를 찾아 AI 도구에 붙여 넣을 글로 복사")).toBeTruthy();
    expect(screen.getByText("담기 → 찾기 → 넘기기")).toBeTruthy();
  });

  it("로그인하지않았을때_화면을그리면_입력줄을두지않는지", () => {
    // given
    // when
    renderView();

    // then
    expect(screen.queryByRole("textbox")).toBeNull();
  });

  it("로그인화면이떠있을때_Google버튼을누르면_google로로그인을요청하는지", () => {
    // given
    const { onSignIn } = renderView();

    // when
    fireEvent.click(button("Google로 계속"));

    // then
    expect(onSignIn).toHaveBeenCalledExactlyOnceWith("google");
  });

  it("로그인화면이떠있을때_GitHub버튼을누르면_github로로그인을요청하는지", () => {
    // given
    const { onSignIn } = renderView();

    // when
    fireEvent.click(button("GitHub로 계속"));

    // then
    expect(onSignIn).toHaveBeenCalledExactlyOnceWith("github");
  });

  it("로그인창이열려있을때_버튼을다시누르면_로그인을다시요청하지않는지", () => {
    // given
    const { onSignIn } = renderView({ isSigningIn: true });

    // when
    fireEvent.click(button("Google로 계속"));
    fireEvent.click(button("GitHub로 계속"));

    // then
    expect(button("Google로 계속").disabled).toBe(true);
    expect(button("GitHub로 계속").disabled).toBe(true);
    expect(onSignIn).not.toHaveBeenCalled();
  });

  it.each<[string, LoggedOutNotice, string, string]>([
    ["취소", { kind: "cancelled" }, "✗ 로그인 취소됨", "로그인 취소됨"],
    ["연결끊김", { kind: "failed", reason: "disconnected" }, "✗ 로그인 실패: 연결 끊김", "로그인 실패:"],
    ["응답없음", { kind: "failed", reason: "timedOut" }, "✗ 로그인 실패: 응답 없음", "로그인 실패:"],
    ["권한거부", { kind: "failed", reason: "denied" }, "✗ 로그인 실패: 권한 거부", "로그인 실패:"],
    ["만료", { kind: "expired" }, "! 로그인 만료 → 다시 로그인", "로그인 만료"],
    ["로그아웃", { kind: "signedOut" }, "✓ 로그아웃됨", "로그아웃됨"],
  ])("알림이_%s일때_화면을그리면_정책문구를_핵심어만_굵게_보여주는지", (_, notice, text, bold) => {
    // given
    // when
    renderView({ notice });

    // then
    const status = screen.getByRole("status");
    expect(shownLine(status)).toBe(text);
    expect(status.querySelector("b")?.textContent).toBe(bold);
  });

  it("알림이없을때_화면을그리면_알림줄을그리지않는지", () => {
    // given
    // when
    renderView();

    // then
    expect(screen.queryByRole("status")).toBeNull();
  });
});
