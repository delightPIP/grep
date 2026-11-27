// 계약(#31 0단계). core/Features/*/Interface의 Swift ViewState·ViewAction을 TS로 옮긴 것이다.
// 순수 뷰(features/*/view.tsx)는 이 타입만 안다. 어댑터(features/*/adapter.tsx)가 BridgeJS 생성 타입을 이 타입으로 바꾼다.
// Swift 쪽과 함께만 바꾼다. 바꿔야 하면 #31에 먼저 알린다.

export type AuthProvider = "google" | "github";

/** ACC-001 `✗ 로그인 실패: <이유>`의 세 가지. disconnected=연결 끊김, timedOut=응답 없음, denied=권한 거부 */
export type SignInFailureReason = "disconnected" | "timedOut" | "denied";

export type LoggedOutNotice =
  | { kind: "cancelled" }
  | { kind: "failed"; reason: SignInFailureReason }
  | { kind: "expired" }
  | { kind: "signedOut" };

/** 로그인 화면(W1·W2·W3·W10). 문구는 뷰가 ACC-001 사용자 문구 원문으로 만든다. */
export type LoggedOutState = {
  notice: LoggedOutNotice | null;
  /** 로그인 창이 열려 있다. 버튼을 눌러도 창을 하나 더 띄우지 않는다(ACC-001 규칙 9). */
  isSigningIn: boolean;
};

export type LoggedOutAction = { kind: "signInTapped"; provider: AuthProvider };

export type TerminalLine =
  | { kind: "prompt"; text: string }
  | { kind: "unknownCommand"; name: string };

/** 터미널 화면. */
export type LoggedInState = {
  /** 상태줄 `자료 N`. 서버에서 받기 전이면 null. */
  itemCount: number | null;
  lines: TerminalLine[];
  /** 입력줄. 로그인 만료 뒤 다시 로그인하면 되살린 값이 들어온다(ACC-001 규칙 7). */
  input: string;
};

export type LoggedInAction =
  | { kind: "inputChanged"; text: string }
  | { kind: "submitted"; text: string };
