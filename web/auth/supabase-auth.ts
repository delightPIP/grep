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
};

// 창을 X로 닫으면 위 이유로 알 수 없어서, 이 시간이 지나면 `응답 없음`으로 끝낸다.
// shortcut: 닫힘을 바로 알지 못한다. 사용자가 기다리기 길다고 하면 콜백 페이지가 heartbeat를 보내는 방식으로 바꾼다.
export const SIGN_IN_TIMEOUT_MS = 2 * 60_000;

export const CALLBACK_CHANNEL = "grep-auth-callback";

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
  authorizeUrl: Promise<{ url: string | null; error: unknown }>,
): Promise<SignInResult> {
  return new Promise((resolve) => {
    let settled = false;
    const settle = (result: SignInResult) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      unsubscribe();
      resolve(result);
    };
    const giveUp = (result: SignInResult) => {
      popup.close();
      settle(result);
    };
    const unsubscribe = deps.subscribeCallback((message) => {
      if (settled) return;
      finishWithCallback(deps.auth, message).then(settle, (error) => settle(failed(errorReason(error))));
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
): Promise<{ url: string | null; error: unknown }> {
  try {
    const { data, error } = await deps.auth.signInWithOAuth({
      provider,
      options: { redirectTo: deps.redirectTo, skipBrowserRedirect: true },
    });
    return { url: data.url, error };
  } catch (error) {
    return { url: null, error };
  }
}

export function createSupabaseAuthService(deps: SupabaseAuthDeps): AuthService {
  let pending: Promise<SignInResult> | null = null;

  return {
    signIn(provider) {
      // 로그인 창은 하나만 띄운다(ACC-001 규칙 9). 진행 중이면 같은 결과를 기다린다.
      if (pending) return pending;
      // 팝업 차단을 피하려고 await 전에, 사용자 동작 안에서 빈 창부터 연다.
      const popup = deps.openPopup();
      if (!popup) return Promise.resolve(failed("denied"));
      pending = waitForCallback(deps, popup, authorizeUrl(deps, provider)).finally(() => {
        pending = null;
      });
      return pending;
    },

    async signOut() {
      // local은 오프라인이어도 이 기기의 세션을 지운다. 지우지 못할 다른 실패는 없어서 결과를 따로 보지 않는다.
      await deps.auth.signOut({ scope: "local" });
    },

    async accessToken() {
      // getSession은 접근 토큰이 만료됐으면 갱신 토큰으로 조용히 새로 받는다(ACC-001 규칙 6).
      try {
        const { data, error } = await deps.auth.getSession();
        if (error || !data.session) return null;
        return data.session.access_token;
      } catch {
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
  });
}
