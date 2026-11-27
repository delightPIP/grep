import { AuthRetryableFetchError, AuthApiError } from "@supabase/supabase-js";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  CANCEL_GRACE_MS,
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

function forAttempt({ search, hash }: CallbackMessage, attempt: string): CallbackMessage {
  const params = new URLSearchParams(search);
  params.set("attempt", attempt);
  return { search: `?${params}`, hash };
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
  let notifyReturn: (() => void) | null = null;
  const unsubscribeReturn = vi.fn(() => {
    notifyReturn = null;
  });
  const deps: SupabaseAuthDeps = {
    auth,
    redirectTo: REDIRECT_TO,
    openPopup: vi.fn(() => popup as unknown as Window),
    subscribeCallback: vi.fn((onMessage) => {
      deliver = onMessage;
      return unsubscribe;
    }),
    subscribeReturn: vi.fn((onReturn) => {
      notifyReturn = onReturn;
      return unsubscribeReturn;
    }),
  };
  /** 마지막 로그인 시도의 번호(redirectTo의 attempt). 제공자는 redirectTo의 쿼리를 그대로 돌려준다. */
  function currentAttempt(): string {
    const calls = vi.mocked(auth.signInWithOAuth).mock.calls;
    const redirectTo = calls.at(-1)?.[0].options?.redirectTo ?? "";
    return new URL(redirectTo).searchParams.get("attempt") ?? "";
  }
  /** 콜백 페이지가 보낸 것처럼 이번 시도의 결과를 넣는다. 구독이 걸릴 때까지 기다린다. */
  async function callback(message: CallbackMessage) {
    await vi.waitFor(() => expect(deliver).not.toBeNull());
    deliver!(forAttempt(message, currentAttempt()));
  }
  /** 가짜 타이머용. vi.waitFor는 가짜 타이머를 스스로 앞당기므로 기다리지 않고 바로 넣는다. */
  function callbackNow(message: CallbackMessage, attempt = currentAttempt()) {
    expect(deliver).not.toBeNull();
    deliver!(forAttempt(message, attempt));
  }
  /** 로그인 창이 닫혀 그렙 창이 다시 포커스를 받은 것처럼 알린다. */
  function returnToGrep() {
    expect(notifyReturn).not.toBeNull();
    notifyReturn!();
  }
  return { deps, auth, popup, unsubscribe, unsubscribeReturn, callback, callbackNow, returnToGrep };
}

describe("supabase AuthService signIn", () => {
  it("브라우저에Google로그인이남아있을때_Google로로그인하면_계정선택화면을요구하는지", async () => {
    // given
    const { deps, auth, callback } = makeDeps();
    const service = createSupabaseAuthService(deps);

    // when
    const pending = service.signIn("google");
    await callback({ search: "?code=abc", hash: "" });
    await pending;

    // then
    expect(auth.signInWithOAuth).toHaveBeenCalledWith({
      provider: "google",
      options: {
        redirectTo: `${REDIRECT_TO}?attempt=1`,
        skipBrowserRedirect: true,
        queryParams: { prompt: "select_account" },
      },
    });
  });

  it("로그인창이열려있을때_인증을마치면_코드를세션으로바꾸고성공을돌려주는지", async () => {
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
      options: { redirectTo: `${REDIRECT_TO}?attempt=1`, skipBrowserRedirect: true },
    });
    expect(popup.location.href).toBe(AUTHORIZE_URL);
    expect(auth.exchangeCodeForSession).toHaveBeenCalledWith("abc");
    expect(unsubscribe).toHaveBeenCalled();
  });

  it("로그인창이열려있을때_다시로그인하면_창을하나더띄우지않는지", async () => {
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

  it("로그인이끝난뒤일때_다시로그인하면_새창을띄우는지", async () => {
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

  it("로그인창이열려있을때_동의화면에서사용자가거부하면_취소로돌려주는지", async () => {
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

  it("로그인창이열려있을때_외부로그인이다른오류로돌아오면_권한거부로돌려주는지", async () => {
    // given
    const { deps, callback } = makeDeps();
    const service = createSupabaseAuthService(deps);

    // when
    const pending = service.signIn("google");
    await callback({ search: "?error=server_error", hash: "" });

    // then
    expect(await pending).toEqual({ kind: "failed", reason: "denied" });
  });

  it("로그인창이열려있을때_코드도오류도없이돌아오면_권한거부로돌려주는지", async () => {
    // given
    const { deps, callback } = makeDeps();
    const service = createSupabaseAuthService(deps);

    // when
    const pending = service.signIn("google");
    await callback({ search: "", hash: "" });

    // then
    expect(await pending).toEqual({ kind: "failed", reason: "denied" });
  });

  it("코드를세션으로바꾸는중일때_네트워크가끊기면_연결끊김으로돌려주는지", async () => {
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

  it("코드를세션으로바꾸는중일때_서버가거절하면_권한거부로돌려주는지", async () => {
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

  it("로그인주소를만드는중일때_네트워크오류가나면_창을닫고연결끊김으로돌려주는지", async () => {
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

  it("브라우저가팝업을막을때_로그인하면_권한거부로돌려주는지", async () => {
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

    it("로그인창이열려있을때_제한시간동안답이없으면_창을닫고응답없음으로돌려주는지", async () => {
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

  // ACC-001 규칙 8. Google은 COOP 때문에 popup.closed를 볼 수 없어서, 그렙 창이 다시 포커스를 받는 것으로 닫힘을 안다.
  describe("로그인 창을 닫음", () => {
    beforeEach(() => {
      vi.useFakeTimers();
    });
    afterEach(() => {
      vi.useRealTimers();
    });

    it("로그인창이열려있을때_결과없이그렙창으로돌아오면_유예시간뒤취소를돌려주는지", async () => {
      // given
      const { deps, popup, unsubscribe, unsubscribeReturn, returnToGrep } = makeDeps();
      const service = createSupabaseAuthService(deps);
      const pending = service.signIn("google");

      // when
      returnToGrep();
      await vi.advanceTimersByTimeAsync(CANCEL_GRACE_MS);

      // then
      expect(await pending).toEqual({ kind: "cancelled" });
      expect(popup.close).toHaveBeenCalled();
      expect(unsubscribe).toHaveBeenCalled();
      expect(unsubscribeReturn).toHaveBeenCalled();
    });

    it("그렙창으로돌아왔을때_유예시간안에결과가오면_성공을돌려주는지", async () => {
      // given
      const { deps, auth, callbackNow, returnToGrep } = makeDeps();
      const service = createSupabaseAuthService(deps);
      const pending = service.signIn("google");

      // when
      returnToGrep();
      await vi.advanceTimersByTimeAsync(CANCEL_GRACE_MS - 1);
      callbackNow({ search: "?code=abc", hash: "" });
      await vi.advanceTimersByTimeAsync(CANCEL_GRACE_MS);

      // then
      expect(await pending).toEqual({ kind: "success" });
      expect(auth.exchangeCodeForSession).toHaveBeenCalledWith("abc");
    });

    it("취소로끝났을때_늦게결과가오면_세션으로바꾸지않는지", async () => {
      // given
      const { deps, auth, returnToGrep } = makeDeps();
      let lateDeliver: ((message: CallbackMessage) => void) | null = null;
      deps.subscribeCallback = vi.fn((onMessage) => {
        lateDeliver = onMessage;
        return () => {};
      });
      const service = createSupabaseAuthService(deps);
      const pending = service.signIn("google");
      returnToGrep();
      await vi.advanceTimersByTimeAsync(CANCEL_GRACE_MS);
      const result = await pending;

      // when
      lateDeliver!({ search: "?code=late", hash: "" });
      await vi.advanceTimersByTimeAsync(0);

      // then
      expect(result).toEqual({ kind: "cancelled" });
      expect(auth.exchangeCodeForSession).not.toHaveBeenCalled();
    });

    it("이전시도의창이남아있을때_새시도중에그창의결과가오면_무시하고새시도의결과로끝나는지", async () => {
      // given
      const { deps, auth, callbackNow, returnToGrep } = makeDeps();
      const service = createSupabaseAuthService(deps);
      const first = service.signIn("google");
      returnToGrep();
      await vi.advanceTimersByTimeAsync(CANCEL_GRACE_MS);
      await first;
      const second = service.signIn("google");

      // when
      callbackNow({ search: "?code=old", hash: "" }, "1");
      await vi.advanceTimersByTimeAsync(0);
      callbackNow({ search: "?code=new", hash: "" });

      // then
      expect(await second).toEqual({ kind: "success" });
      expect(auth.exchangeCodeForSession).toHaveBeenCalledTimes(1);
      expect(auth.exchangeCodeForSession).toHaveBeenCalledWith("new");
    });

    it("결과를받았을때_교환이제한시간을넘겨끝나면_응답없음이아니라성공을돌려주는지", async () => {
      // given
      let finishExchange: (() => void) | null = null;
      const { deps, callbackNow } = makeDeps({
        exchangeCodeForSession: vi.fn(
          () =>
            new Promise((resolve) => {
              finishExchange = () => resolve({ data: { session: fakeSession("t"), user: {} }, error: null });
            }),
        ) as unknown as AuthClient["exchangeCodeForSession"],
      });
      const service = createSupabaseAuthService(deps);
      const pending = service.signIn("google");
      await vi.advanceTimersByTimeAsync(SIGN_IN_TIMEOUT_MS - 1);
      callbackNow({ search: "?code=abc", hash: "" });

      // when
      await vi.advanceTimersByTimeAsync(SIGN_IN_TIMEOUT_MS);
      finishExchange!();

      // then
      expect(await pending).toEqual({ kind: "success" });
    });
  });
});

describe("supabase AuthService accessToken", () => {
  it("세션이있을때_토큰을요청하면_접근토큰을돌려주는지", async () => {
    // given
    const { deps } = makeDeps();
    const service = createSupabaseAuthService(deps);

    // when
    const token = await service.accessToken();

    // then
    expect(token).toBe("token-1");
  });

  it("세션이없을때_토큰을요청하면_null을돌려주는지", async () => {
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

  it("갱신토큰이없을때_토큰을요청하면_null을돌려주는지", async () => {
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

  it("토큰을받은적이있을때_네트워크가끊겨갱신에실패하면_마지막토큰을돌려주는지", async () => {
    // given
    const getSession = vi
      .fn()
      .mockResolvedValueOnce({ data: { session: fakeSession("token-1") }, error: null })
      .mockResolvedValueOnce({ data: { session: null }, error: new AuthRetryableFetchError("Failed to fetch", 0) });
    const { deps } = makeDeps({ getSession: getSession as unknown as AuthClient["getSession"] });
    const service = createSupabaseAuthService(deps);
    await service.accessToken();

    // when
    const token = await service.accessToken();

    // then
    expect(token).toBe("token-1");
  });

  it("로그아웃했을때_네트워크가끊겨갱신에실패하면_null을돌려주는지", async () => {
    // given
    const getSession = vi
      .fn()
      .mockResolvedValueOnce({ data: { session: fakeSession("token-1") }, error: null })
      .mockResolvedValueOnce({ data: { session: null }, error: new AuthRetryableFetchError("Failed to fetch", 0) });
    const { deps } = makeDeps({ getSession: getSession as unknown as AuthClient["getSession"] });
    const service = createSupabaseAuthService(deps);
    await service.accessToken();
    await service.signOut();

    // when
    const token = await service.accessToken();

    // then
    expect(token).toBeNull();
  });

  it("세션저장소가깨졌을때_토큰을요청하면_null을돌려주는지", async () => {
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
  it("로그인한상태일때_로그아웃하면_이기기의세션만끝내는지", async () => {
    // given
    const { deps, auth } = makeDeps();
    const service = createSupabaseAuthService(deps);

    // when
    await service.signOut();

    // then
    expect(auth.signOut).toHaveBeenCalledWith({ scope: "local" });
  });
});
