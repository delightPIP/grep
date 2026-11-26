import { AuthRetryableFetchError, AuthApiError } from "@supabase/supabase-js";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  SIGN_IN_TIMEOUT_MS,
  createSupabaseAuthService,
  type AuthClient,
  type CallbackMessage,
  type SupabaseAuthDeps,
} from "./supabase-auth";

const AUTHORIZE_URL = "https://example.supabase.co/auth/v1/authorize?provider=google";
const REDIRECT_TO = "http://localhost:5173/auth-callback.html";

function fakeSession(token: string) {
  return { access_token: token } as never;
}

function makeDeps(overrides: Partial<AuthClient> = {}) {
  let deliver: ((message: CallbackMessage) => void) | null = null;
  const popup = { location: { href: "about:blank" }, close: vi.fn() };
  const auth: AuthClient = {
    signInWithOAuth: vi.fn(async () => ({
      data: { provider: "google", url: AUTHORIZE_URL },
      error: null,
    })) as unknown as AuthClient["signInWithOAuth"],
    exchangeCodeForSession: vi.fn(async () => ({
      data: { session: fakeSession("t"), user: {} },
      error: null,
    })) as unknown as AuthClient["exchangeCodeForSession"],
    signOut: vi.fn(async () => ({ error: null })) as unknown as AuthClient["signOut"],
    getSession: vi.fn(async () => ({
      data: { session: fakeSession("token-1") },
      error: null,
    })) as unknown as AuthClient["getSession"],
    ...overrides,
  };
  const unsubscribe = vi.fn(() => {
    deliver = null;
  });
  const deps: SupabaseAuthDeps = {
    auth,
    redirectTo: REDIRECT_TO,
    openPopup: vi.fn(() => popup as unknown as Window),
    subscribeCallback: vi.fn((onMessage) => {
      deliver = onMessage;
      return unsubscribe;
    }),
  };
  /** 콜백 페이지가 보낸 것처럼 결과를 넣는다. 구독이 걸릴 때까지 기다린다. */
  async function callback(message: CallbackMessage) {
    await vi.waitFor(() => expect(deliver).not.toBeNull());
    deliver!(message);
  }
  return { deps, auth, popup, unsubscribe, callback };
}

describe("supabase AuthService signIn", () => {
  it("로그인창에서_인증을마치면_코드를_세션으로바꾸고_성공을_돌려주는지", async () => {
    // given
    const { deps, auth, popup, unsubscribe, callback } = makeDeps();
    const service = createSupabaseAuthService(deps);

    // when
    const pending = service.signIn("github");
    await callback({ search: "?code=abc", hash: "" });
    const result = await pending;

    // then
    expect(result).toEqual({ kind: "success" });
    expect(auth.signInWithOAuth).toHaveBeenCalledWith({
      provider: "github",
      options: { redirectTo: REDIRECT_TO, skipBrowserRedirect: true },
    });
    expect(popup.location.href).toBe(AUTHORIZE_URL);
    expect(auth.exchangeCodeForSession).toHaveBeenCalledWith("abc");
    expect(unsubscribe).toHaveBeenCalled();
  });

  it("로그인창이_열려있을때_다시로그인하면_창을_하나더_띄우지않는지", async () => {
    // given
    const { deps, callback } = makeDeps();
    const service = createSupabaseAuthService(deps);

    // when
    const first = service.signIn("google");
    const second = service.signIn("github");
    await callback({ search: "?code=abc", hash: "" });

    // then
    expect(second).toBe(first);
    expect(deps.openPopup).toHaveBeenCalledTimes(1);
    expect(await second).toEqual({ kind: "success" });
  });

  it("로그인이_끝난뒤에_다시로그인하면_새창을_띄우는지", async () => {
    // given
    const { deps, callback } = makeDeps();
    const service = createSupabaseAuthService(deps);
    const first = service.signIn("google");
    await callback({ search: "?code=abc", hash: "" });
    await first;

    // when
    const second = service.signIn("google");
    await callback({ search: "?code=def", hash: "" });

    // then
    expect(await second).toEqual({ kind: "success" });
    expect(deps.openPopup).toHaveBeenCalledTimes(2);
  });

  it("동의화면에서_사용자가_거부하면_취소로_돌려주는지", async () => {
    // given
    const { deps, auth, callback } = makeDeps();
    const service = createSupabaseAuthService(deps);

    // when
    const pending = service.signIn("google");
    await callback({ search: "", hash: "#error=access_denied&error_description=denied" });

    // then
    expect(await pending).toEqual({ kind: "cancelled" });
    expect(auth.exchangeCodeForSession).not.toHaveBeenCalled();
  });

  it("외부로그인이_다른오류로_돌아오면_권한거부로_돌려주는지", async () => {
    // given
    const { deps, callback } = makeDeps();
    const service = createSupabaseAuthService(deps);

    // when
    const pending = service.signIn("google");
    await callback({ search: "?error=server_error", hash: "" });

    // then
    expect(await pending).toEqual({ kind: "failed", reason: "denied" });
  });

  it("코드도_오류도없이_돌아오면_권한거부로_돌려주는지", async () => {
    // given
    const { deps, callback } = makeDeps();
    const service = createSupabaseAuthService(deps);

    // when
    const pending = service.signIn("google");
    await callback({ search: "", hash: "" });

    // then
    expect(await pending).toEqual({ kind: "failed", reason: "denied" });
  });

  it("코드를_바꾸는중_네트워크가끊기면_연결끊김으로_돌려주는지", async () => {
    // given
    const { deps, callback } = makeDeps({
      exchangeCodeForSession: vi.fn(async () => ({
        data: { session: null, user: null },
        error: new AuthRetryableFetchError("Failed to fetch", 0),
      })) as unknown as AuthClient["exchangeCodeForSession"],
    });
    const service = createSupabaseAuthService(deps);

    // when
    const pending = service.signIn("google");
    await callback({ search: "?code=abc", hash: "" });

    // then
    expect(await pending).toEqual({ kind: "failed", reason: "disconnected" });
  });

  it("코드를_서버가_거절하면_권한거부로_돌려주는지", async () => {
    // given
    const { deps, callback } = makeDeps({
      exchangeCodeForSession: vi.fn(async () => ({
        data: { session: null, user: null },
        error: new AuthApiError("invalid grant", 400, "bad_code_verifier"),
      })) as unknown as AuthClient["exchangeCodeForSession"],
    });
    const service = createSupabaseAuthService(deps);

    // when
    const pending = service.signIn("google");
    await callback({ search: "?code=abc", hash: "" });

    // then
    expect(await pending).toEqual({ kind: "failed", reason: "denied" });
  });

  it("로그인주소를_만들다_네트워크오류가나면_창을닫고_연결끊김으로_돌려주는지", async () => {
    // given
    const { deps, popup } = makeDeps({
      signInWithOAuth: vi.fn(async () => ({
        data: { provider: "google", url: null },
        error: new AuthRetryableFetchError("Failed to fetch", 0),
      })) as unknown as AuthClient["signInWithOAuth"],
    });
    const service = createSupabaseAuthService(deps);

    // when
    const result = await service.signIn("google");

    // then
    expect(result).toEqual({ kind: "failed", reason: "disconnected" });
    expect(popup.close).toHaveBeenCalled();
  });

  it("브라우저가_로그인창을_막으면_권한거부로_돌려주는지", async () => {
    // given
    const { deps, auth } = makeDeps();
    deps.openPopup = vi.fn(() => null);
    const service = createSupabaseAuthService(deps);

    // when
    const result = await service.signIn("google");

    // then
    expect(result).toEqual({ kind: "failed", reason: "denied" });
    expect(auth.signInWithOAuth).not.toHaveBeenCalled();
  });

  describe("시간 초과", () => {
    beforeEach(() => {
      vi.useFakeTimers();
    });
    afterEach(() => {
      vi.useRealTimers();
    });

    it("로그인창이_제한시간동안_답이없으면_창을닫고_응답없음으로_돌려주는지", async () => {
      // given
      const { deps, popup, unsubscribe } = makeDeps();
      const service = createSupabaseAuthService(deps);
      const pending = service.signIn("google");

      // when
      await vi.advanceTimersByTimeAsync(SIGN_IN_TIMEOUT_MS);

      // then
      expect(await pending).toEqual({ kind: "failed", reason: "timedOut" });
      expect(popup.close).toHaveBeenCalled();
      expect(unsubscribe).toHaveBeenCalled();
    });
  });
});

describe("supabase AuthService accessToken", () => {
  it("세션이_있을때_토큰을요청하면_접근토큰을_돌려주는지", async () => {
    // given
    const { deps } = makeDeps();
    const service = createSupabaseAuthService(deps);

    // when
    const token = await service.accessToken();

    // then
    expect(token).toBe("token-1");
  });

  it("세션이_없을때_토큰을요청하면_null을_돌려주는지", async () => {
    // given
    const { deps } = makeDeps({
      getSession: vi.fn(async () => ({
        data: { session: null },
        error: null,
      })) as unknown as AuthClient["getSession"],
    });
    const service = createSupabaseAuthService(deps);

    // when
    const token = await service.accessToken();

    // then
    expect(token).toBeNull();
  });

  it("토큰갱신에_실패하면_null을_돌려주는지", async () => {
    // given
    const { deps } = makeDeps({
      getSession: vi.fn(async () => ({
        data: { session: null },
        error: new AuthApiError("refresh token not found", 400, "refresh_token_not_found"),
      })) as unknown as AuthClient["getSession"],
    });
    const service = createSupabaseAuthService(deps);

    // when
    const token = await service.accessToken();

    // then
    expect(token).toBeNull();
  });

  it("세션조회가_예외를던지면_null을_돌려주는지", async () => {
    // given
    const { deps } = makeDeps({
      getSession: vi.fn(async () => {
        throw new Error("storage broken");
      }) as unknown as AuthClient["getSession"],
    });
    const service = createSupabaseAuthService(deps);

    // when
    const token = await service.accessToken();

    // then
    expect(token).toBeNull();
  });
});

describe("supabase AuthService signOut", () => {
  it("로그아웃하면_이기기의_세션만_끝내는지", async () => {
    // given
    const { deps, auth } = makeDeps();
    const service = createSupabaseAuthService(deps);

    // when
    await service.signOut();

    // then
    expect(auth.signOut).toHaveBeenCalledWith({ scope: "local" });
  });
});
