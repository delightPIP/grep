-- 계약 2: 묶음(ARC-003), 찾아두기(ARC-012), AI 도구 연결(ACC-002, ARC-009, ADR-BCK-015), 북마크 가져오기(F8).
-- 뜻이 가까운 찾기의 임베딩 열(ADR-BCK-016)은 pgvector가 없는 테스트 이미지 때문에 #128에서 V5로 따로 넣는다.

-- 묶음: 이름은 사용자 안에서 유일하고 영문 대소문자를 가리지 않는다(ARC-003 규칙 26). name은 처음 만든 표기
CREATE TABLE bundles (
    id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    name       text        NOT NULL CHECK (char_length(name) BETWEEN 1 AND 20),
    created_at timestamptz NOT NULL DEFAULT now(),
    -- 목록은 최근에 바뀐 순(규칙 18). 넣기·빼기 때 서버가 넣는다
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX bundles_user_name_key ON bundles (user_id, lower(name));

-- 자료 하나는 여러 묶음에 들 수 있다(규칙 17). 휴지통 자료는 행을 남기고 보일 때만 뺀다(규칙 25). 영구 삭제는 CASCADE
CREATE TABLE bundle_items (
    bundle_id uuid        NOT NULL REFERENCES bundles (id) ON DELETE CASCADE,
    item_id   uuid        NOT NULL REFERENCES items (id) ON DELETE CASCADE,
    added_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (bundle_id, item_id)
);
CREATE INDEX bundle_items_item_id_idx ON bundle_items (item_id);

-- 찾아두기: query는 공백 정리 뒤 검색어 그대로(ARC-012 규칙 2·3), 1~40자
CREATE TABLE saved_searches (
    id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    query      text        NOT NULL CHECK (char_length(query) BETWEEN 1 AND 40),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, query)
);

-- OAuth 클라이언트(AI 도구). 동적 등록으로 만들어진다(ADR-BCK-015 결정 1)
CREATE TABLE oauth_clients (
    id            text        PRIMARY KEY,
    name          text        NOT NULL,
    redirect_uris text[]      NOT NULL,
    created_at    timestamptz NOT NULL DEFAULT now()
);

-- 인가 코드(PKCE). 짧게 살고 한 번만 쓴다. 코드 원문은 두지 않고 해시만
CREATE TABLE oauth_codes (
    code_hash      text        PRIMARY KEY,
    client_id      text        NOT NULL REFERENCES oauth_clients (id) ON DELETE CASCADE,
    user_id        uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    redirect_uri   text        NOT NULL,
    code_challenge text        NOT NULL,
    expires_at     timestamptz NOT NULL,
    used_at        timestamptz
);

-- 연결 하나 = 승인 한 번(ACC-002). 토큰은 해시만. number는 사용자별 연결 번호(`연결 끊기 <번호>`)
CREATE TABLE connections (
    id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id            uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    number             integer     NOT NULL CHECK (number > 0),
    client_id          text        NOT NULL REFERENCES oauth_clients (id),
    access_token_hash  text        NOT NULL UNIQUE,
    refresh_token_hash text        UNIQUE,
    access_expires_at  timestamptz NOT NULL,
    created_at         timestamptz NOT NULL DEFAULT now(),
    last_read_at       timestamptz,
    -- 끊김. reason: user(연결 끊기), revoked(모든 기기 로그아웃), expired(토큰 만료)
    ended_at           timestamptz,
    end_reason         text        CHECK (end_reason IN ('user', 'revoked', 'expired')),
    -- 사용자가 직접 끊지 않은 끊김을 다음에 열 때 한 번 알렸는지(ACC-002 규칙 11)
    notice_seen_at     timestamptz,
    UNIQUE (user_id, number),
    CHECK ((ended_at IS NULL) = (end_reason IS NULL))
);
ALTER TABLE users ADD COLUMN last_connection_number integer NOT NULL DEFAULT 0;

-- 북마크 가져오기(F8). 진행은 표 한 줄로 보인다
CREATE TABLE imports (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    state       text        NOT NULL DEFAULT 'running' CHECK (state IN ('running', 'finished')),
    total       integer     NOT NULL CHECK (total BETWEEN 0 AND 200),
    done        integer     NOT NULL DEFAULT 0,
    saved       integer     NOT NULL DEFAULT 0,
    skipped     integer     NOT NULL DEFAULT 0,
    failed      integer     NOT NULL DEFAULT 0,
    over_limit  integer     NOT NULL DEFAULT 0,
    failed_urls text[]      NOT NULL DEFAULT '{}',
    created_at  timestamptz NOT NULL DEFAULT now(),
    finished_at timestamptz
);

-- 가져온 자료는 처리 작업을 바로 만들지 않고 처음 열거나 넘길 때 만든다(user-flow 10절, ADR-BCK-008)
ALTER TABLE items ADD COLUMN processing_deferred boolean NOT NULL DEFAULT false;

ALTER TABLE bundles ENABLE ROW LEVEL SECURITY;
ALTER TABLE bundle_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_searches ENABLE ROW LEVEL SECURITY;
ALTER TABLE oauth_clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE oauth_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE imports ENABLE ROW LEVEL SECURITY;
