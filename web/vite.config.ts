import react from "@vitejs/plugin-react";
import { defineConfig } from "vitest/config";

// Google OAuth 원본과 Supabase Redirect URLs에 http://localhost:5173 이 등록돼 있다.
// 포트가 바뀌면 로그인이 깨지므로 다른 포트로 넘어가지 않게 고정한다.
export default defineConfig({
  plugins: [react()],
  server: { port: 5173, strictPort: true },
  test: {
    environment: "jsdom",
    // wasm 빌드 결과가 없어도 돌아가는 테스트만 둔다(순수 뷰, 로그인 모듈).
    include: ["features/**/*.test.{ts,tsx}", "auth/**/*.test.{ts,tsx}", "support/**/*.test.{ts,tsx}", "ui/**/*.test.{ts,tsx}"],
  },
});
