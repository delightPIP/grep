-- #31 로그인. ACC-001, COM-006, ADR-BCK-006.
-- 계정은 (로그인 방식, 외부 계정 ID) 한 쌍이다. 이메일이 같아도 합치지 않는다(ACC-001 규칙 4).
-- Supabase auth.users를 외래 키로 참조하지 않는다(ADR-BCK-006 결정 3).

CREATE TABLE users (
    id            uuid        PRIMARY KEY,
    auth_provider text        NOT NULL CHECK (auth_provider IN ('google', 'github')),
    external_id   text        NOT NULL,
    created_at    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (auth_provider, external_id)
);

-- 세션 만료(30일 미사용, 90일 최대)는 서버가 판정한다(ACC-001 비고).
-- id는 Supabase 접근 토큰의 session_id. started_at은 서버가 이 세션을 처음 본 때다.
CREATE TABLE sessions (
    id           uuid        PRIMARY KEY,
    user_id      uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    started_at   timestamptz NOT NULL,
    last_seen_at timestamptz NOT NULL
);

CREATE INDEX sessions_user_id_idx ON sessions (user_id);

-- 서버는 소유자 권한으로 접속한다. RLS는 Data API 등 다른 길로 열릴 때를 막는 안전장치다.
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
