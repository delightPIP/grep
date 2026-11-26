// 임시 로그인 모듈. 외부 로그인 없이 바로 성공한다. wasm 코어가 브라우저에서 도는지 확인하는 용도다.
// C 갈래의 auth/supabase-auth.ts가 병합되면 app.ts에서 그것으로 바꾸고 이 파일을 지운다.
import type { AuthService, SignInResult } from "../auth/auth-service";

export class DevAuthService implements AuthService {
  #token: string | null = null;

  async signIn(): Promise<SignInResult> {
    this.#token = "dev-token";
    return { kind: "success" };
  }

  async signOut(): Promise<void> {
    this.#token = null;
  }

  async accessToken(): Promise<string | null> {
    return this.#token;
  }
}
