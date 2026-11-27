// AuthService의 supabase-js 구현. 웹의 로그인 코드는 이 모듈 하나에 모은다(ADR-BCK-006 결정 2·7).
// supabase-js는 로그인에만 쓴다. 데이터 API(from·rpc·storage)는 부르지 않는다.
//
// 흐름: 팝업을 열고 → PKCE 로그인 주소로 보낸다 → 제공자가 public/auth-callback.html로 돌려보낸다 →
// 콜백 페이지가 주소의 code/error를 BroadcastChannel로 넘기고 창을 닫는다 → 여기서 code를 세션으로 바꾼다.
// Google 로그인 페이지는 Cross-Origin-Opener-Policy: same-origin을 보내서 여는 쪽이 팝업과의 연결을 잃는다
// (popup.closed가 곧바로 true가 된다). 그래서 window.opener·popup.closed 대신 BroadcastChannel로 결과를 받는다.
import {
  createClient,
  isAuthRetryableFetchError,
  type SupabaseClient,
} from "@supabase/supabase-js";
import type { AuthProvider, SignInFailureReason } from "../support/view-state";
import type { AuthService, SignInResult } from "./auth-service";

export type AuthClient = Pick<
  SupabaseClient["auth"],
  "signInWithOAuth" | "exchangeCodeForSession" | "signOut" | "getSession"
>;

/** 콜백 페이지가 보내는 것. 돌아온 주소의 search와 hash 그대로다. */
export type CallbackMessage = { search: string; hash: string };

export type SupabaseAuthDeps = {
  auth: AuthClient;
  /** 제공자가 돌려보낼 주소. Supabase Redirect URLs에 등록돼 있어야 한다. */
  redirectTo: string;
  /** 빈 팝업을 연다. 막히면 null. */
  openPopup: () => Window | null;
  /** 콜백 결과를 구독한다. 돌려준 함수로 구독을 끊는다. */
  subscribeCallback: (onMessage: (message: CallbackMessage) => void) => () => void;
  /** 로그인 창에서 그렙 창으로 돌아온 때(포커스·보이기)를 구독한다. 돌려준 함수로 구독을 끊는다. */
  subscribeReturn: (onReturn: () => void) => () => void;
};

// 창 닫힘은 popup.closed로 알 수 없다(위 COOP). 대신 그렙 창이 다시 포커스를 받고 이 시간 안에 결과가 없으면
// 사용자가 창을 닫은 것으로 보고 `로그인 취소됨`으로 끝낸다(ACC-001 규칙 8, ADR-WEB-013).
// 로그인 도중 그렙 창을 직접 누르면 취소로 오판한다. 그때 늦게 온 결과는 버리고 다시 누르게 한다.
export const CANCEL_GRACE_MS = 1_500;

// 포커스 신호가 없는 환경(창 대신 탭으로 연 경우 등)의 안전망. 이 시간이 지나면 `응답 없음`으로 끝낸다.
export const SIGN_IN_TIMEOUT_MS = 2 * 60_000;

export const CALLBACK_CHANNEL = "grep-auth-callback";

/** redirectTo에 붙이는 로그인 시도 번호. 제공자를 거쳐 콜백 주소에 그대로 돌아온다. */
const ATTEMPT_PARAM = "attempt";

const failed = (reason: SignInFailureReason): SignInResult => ({ kind: "failed", reason });

function errorReason(error: unknown): SignInFailureReason {
  return isAuthRetryableFetchError(error) ? "disconnected" : "denied";
}

function readCallback({ search, hash }: CallbackMessage): URLSearchParams {
  const params = new URLSearchParams(search);
  new URLSearchParams(hash.replace(/^#/, "")).forEach((value, key) => params.set(key, value));
  return params;
}

async function finishWithCallback(auth: AuthClient, message: CallbackMessage): Promise<SignInResult> {
  const params = readCallback(message);
  const error = params.get("error");
  // 동의 화면에서 사용자가 취소·거부를 누르면 access_denied로 온다. ACC-001의 `로그인 취소됨`으로 본다.
  if (error === "access_denied") return { kind: "cancelled" };
  const code = params.get("code");
  if (error || !code) return failed("denied");
  const { error: exchangeError } = await auth.exchangeCodeForSession(code);
  return exchangeError ? failed(errorReason(exchangeError)) : { kind: "success" };
}

function waitForCallback(
  deps: SupabaseAuthDeps,
  popup: Window,
  attempt: string,
  authorizeUrl: Promise<{ url: string | null; error: unknown }>,
): Promise<SignInResult> {
  return new Promise((resolve) => {
    let settled = false;
    let received = false;
    let graceTimer: ReturnType<typeof setTimeout> | undefined;
    const settle = (result: SignInResult) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      clearTimeout(graceTimer);
      unsubscribe();
      unsubscribeReturn();
      resolve(result);
    };
    const giveUp = (result: SignInResult) => {
      popup.close();
      settle(result);
    };
    const unsubscribe = deps.subscribeCallback((message) => {
      if (settled) return;
      // 취소로 끝난 앞 시도의 창이 남아 있다가 보낸 결과는 이번 시도의 PKCE 검증값과 맞지 않는다. 버린다.
      if (readCallback(message).get(ATTEMPT_PARAM) !== attempt) return;
      received = true;
      // 결과를 받았으면 교환이 늦어져도 시간 초과로 끝내지 않는다.
      clearTimeout(timer);
      clearTimeout(graceTimer);
      finishWithCallback(deps.auth, message).then(settle, (error) => settle(failed(errorReason(error))));
    });
    const unsubscribeReturn = deps.subscribeReturn(() => {
      if (settled || received) return;
      clearTimeout(graceTimer);
      graceTimer = setTimeout(() => giveUp({ kind: "cancelled" }), CANCEL_GRACE_MS);
    });
    const timer = setTimeout(() => giveUp(failed("timedOut")), SIGN_IN_TIMEOUT_MS);
    authorizeUrl.then(({ url, error }) => {
      if (error || !url) giveUp(failed(errorReason(error)));
      else popup.location.href = url;
    });
  });
}

async function authorizeUrl(
  deps: SupabaseAuthDeps,
  provider: AuthProvider,
  attempt: string,
): Promise<{ url: string | null; error: unknown }> {
  try {
    const redirectTo = new URL(deps.redirectTo);
    redirectTo.searchParams.set(ATTEMPT_PARAM, attempt);
    const options = { redirectTo: redirectTo.href, skipBrowserRedirect: true };
    const { data, error } = await deps.auth.signInWithOAuth({
      provider,
      // `로그아웃`은 그렙 세션만 지우고 브라우저의 Google 로그인은 남긴다. 계정 선택 없이 남은 계정으로
      // 들어가지 않게 항상 고르게 한다(데모 계정 B 전환, AI 로그 081 발견 사항 4).
      options: provider === "google" ? { ...options, queryParams: { prompt: "select_account" } } : options,
    });
    return { url: data.url, error };
  } catch (error) {
    return { url: null, error };
  }
}

export function createSupabaseAuthService(deps: SupabaseAuthDeps): AuthService {
  let pending: Promise<SignInResult> | null = null;
  let attempts = 0;
  /** 마지막으로 받은 접근 토큰. 네트워크가 끊겨 갱신하지 못할 때 세션 만료로 오인하지 않으려고 둔다. */
  let lastToken: string | null = null;

  return {
    signIn(provider) {
      // 로그인 창은 하나만 띄운다(ACC-001 규칙 9). 진행 중이면 같은 결과를 기다린다.
      if (pending) return pending;
      // 팝업 차단을 피하려고 await 전에, 사용자 동작 안에서 빈 창부터 연다.
      const popup = deps.openPopup();
      if (!popup) return Promise.resolve(failed("denied"));
      attempts += 1;
      const attempt = String(attempts);
      pending = waitForCallback(deps, popup, attempt, authorizeUrl(deps, provider, attempt)).finally(() => {
        pending = null;
      });
      return pending;
    },

    async signOut() {
      lastToken = null;
      // local은 오프라인이어도 이 기기의 세션을 지운다. 지우지 못할 다른 실패는 없어서 결과를 따로 보지 않는다.
      await deps.auth.signOut({ scope: "local" });
    },

    async signOutEverywhere() {
      lastToken = null;
      // global은 서버의 모든 갱신 토큰을 끊는다(ACC-002 규칙 4). 다른 기기는 접근 토큰 만료 때(최대 1시간) 로그아웃된다.
      await deps.auth.signOut({ scope: "global" });
    },

    async accessToken() {
      // getSession은 접근 토큰이 만료됐으면 갱신 토큰으로 조용히 새로 받는다(ACC-001 규칙 6).
      // 갱신이 네트워크 문제로 실패하면 마지막 토큰을 돌려준다. 그 요청은 서버에 닿지 못해 `연결 끊김`이 되고,
      // 세션 만료(로그인 화면)로 보내지 않는다. 서버에 닿으면 만료된 토큰은 서버가 401로 판정한다.
      try {
        const { data, error } = await deps.auth.getSession();
        if (error && isAuthRetryableFetchError(error)) return lastToken;
        lastToken = error || !data.session ? null : data.session.access_token;
        return lastToken;
      } catch (error) {
        if (isAuthRetryableFetchError(error)) return lastToken;
        lastToken = null;
        return null;
      }
    },
  };
}

function subscribeBroadcast(onMessage: (message: CallbackMessage) => void): () => void {
  const channel = new BroadcastChannel(CALLBACK_CHANNEL);
  channel.onmessage = ({ data }: MessageEvent<unknown>) => {
    // 같은 출처에서만 오지만 모양은 확인한다.
    if (typeof data !== "object" || data === null) return;
    const { search, hash } = data as Record<string, unknown>;
    if (typeof search === "string" && typeof hash === "string") onMessage({ search, hash });
  };
  return () => channel.close();
}

function subscribeWindowReturn(onReturn: () => void): () => void {
  const onVisible = () => {
    if (document.visibilityState === "visible") onReturn();
  };
  window.addEventListener("focus", onReturn);
  document.addEventListener("visibilitychange", onVisible);
  return () => {
    window.removeEventListener("focus", onReturn);
    document.removeEventListener("visibilitychange", onVisible);
  };
}

/** 브라우저용 기본 조립. 환경 값은 web/.env.local(공개 값만)에서 읽는다. */
export function createBrowserAuthService(): AuthService {
  const url = import.meta.env.VITE_SUPABASE_URL;
  const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) {
    throw new Error("VITE_SUPABASE_URL·VITE_SUPABASE_PUBLISHABLE_KEY가 없다. web/.env.example을 보고 web/.env.local을 만든다.");
  }
  const client = createClient(url, key, {
    auth: { flowType: "pkce", detectSessionInUrl: false, persistSession: true, autoRefreshToken: true },
  });
  return createSupabaseAuthService({
    auth: client.auth,
    redirectTo: new URL("auth-callback.html", window.location.origin + import.meta.env.BASE_URL).href,
    openPopup: () => window.open("about:blank", "grep-login", "popup,width=480,height=640"),
    subscribeCallback: subscribeBroadcast,
    subscribeReturn: subscribeWindowReturn,
  });
}
