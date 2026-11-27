// 계약(#31 0단계). core/Core/Sources/AuthService.swift를 JS 쪽에서 구현할 모양이다.
// C 갈래가 supabase-js로 구현하고(ADR-BCK-006 결정 2·7: 로그인에만 쓰고 이 모듈 하나에 모은다),
// B 갈래가 BridgeJS로 Swift AuthService에 잇는다.

import type { AuthProvider, SignInFailureReason } from "../support/view-state";

export type SignInResult =
  | { kind: "success" }
  | { kind: "cancelled" }
  | { kind: "failed"; reason: SignInFailureReason };

export interface AuthService {
  /** 외부 로그인 창을 열고 끝날 때까지 기다린다. */
  signIn(provider: AuthProvider): Promise<SignInResult>;
  /** 이 기기의 세션을 끝낸다. */
  signOut(): Promise<void>;
  /** 유효한 접근 토큰. 만료됐으면 조용히 갱신한다(ACC-001 규칙 6). 세션이 없거나 갱신에 실패하면 null. */
  accessToken(): Promise<string | null>;
}
