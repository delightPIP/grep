-- #56 데모 범위 계약: 자료(items), 파일 업로드 자리(uploads), 처리 작업 큐(item_jobs).
-- 근거: ARC-001(번호), ARC-002(태그), ARC-004(요약 출처), ARC-005(상태), ARC-008(휴지통),
--       COM-001(같은 자료), COM-004(형식), COM-006(사용자별), ADR-BCK-008(모델·프롬프트 버전).
-- API는 자료를 사용자별 번호로만 가리킨다. id(uuid)는 DB 안에서만 쓴다.

-- 검색은 PGroonga(Supabase 확장). 쿼리는 서버의 검색 어댑터 한 곳에만 둔다.
CREATE EXTENSION IF NOT EXISTS pgroonga;

-- ARC-001: 사용자마다 마지막으로 발급한 번호. 지운 번호는 다시 쓰지 않으므로 MAX(number)가 아니라 이 값으로 센다.
-- 발급은 `UPDATE users SET last_item_number = last_item_number + 1 ... RETURNING`을 자료 INSERT와 한 트랜잭션에서 한다.
-- 행 잠금이 같은 사용자의 동시 저장을 차례로 세운다(규칙 3).
ALTER TABLE users ADD COLUMN last_item_number bigint NOT NULL DEFAULT 0;

CREATE TABLE items (
    id                     uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    number                 bigint      NOT NULL CHECK (number > 0),
    kind                   text        NOT NULL CHECK (kind IN ('link', 'text', 'file')),

    -- 링크(COM-001 정규화 주소로 같은 자료 판정)
    url                    text,
    normalized_url         text,
    -- 붙여 넣은 글
    text_body              text,
    -- 파일(COM-004). 원본은 비공개 버킷 items의 object_path. content_hash는 원본 바이트 SHA-256(hex)
    object_path            text,
    file_name              text,
    file_format            text        CHECK (file_format IN ('pdf', 'md', 'txt', 'docx', 'png', 'jpeg', 'webp', 'heic')),
    file_size              bigint      CHECK (file_size >= 0),
    content_hash           text,

    -- 목록·넘길 글에 쓰는 값. 붙여 넣은 글의 제목은 첫 줄 24자까지(04 질문 6)
    title                  text        NOT NULL,
    -- 출처: 링크는 호스트, 파일은 형식. 없을 수 있다
    source                 text,

    -- ARC-005 처리 상태 다섯 가지
    status                 text        NOT NULL DEFAULT 'received'
                                       CHECK (status IN ('received', 'processing', 'ready', 'blocked', 'failed')),
    -- blocked 이유(ARC-005 사용자 문구: 로그인 필요, 접근 거부, 열지 않는 주소) 또는 COM-004 규칙 6(암호 걸린 PDF, 글자 없음)
    blocked_reason         text        CHECK (blocked_reason IN ('login_required', 'access_denied', 'disallowed_url',
                                                                 'encrypted', 'no_text')),
    -- 일부만 읽었으면 요약 끝에 붙일 표시(ARC-004 규칙 8). 예: '앞 3쪽만 읽음'
    partial_note           text,

    -- ARC-004: 목록용 한 줄 요약, 넘기기용 요약(AI), 직접 고친 요약(사용자, AI보다 우선)
    list_summary           text,
    handoff_summary        text,
    user_summary           text,
    -- ADR-BCK-008 결정 3
    summary_model          text,
    summary_prompt_version text,
    -- ARC-002 자동 태그('#' 없이 저장)
    tags                   text[]      NOT NULL DEFAULT '{}',
    -- 찾기 대상 글(제목·출처·요약·태그·본문 일부). 서버가 처리 단계마다 다시 만든다
    search_text            text        NOT NULL DEFAULT '',

    -- POST /items Idempotency-Key. 같은 키로 다시 오면 처음 결과를 돌려준다
    idempotency_key        uuid,
    created_at             timestamptz NOT NULL DEFAULT now(),
    -- 트리거 없음. 서버가 UPDATE마다 직접 넣는다
    updated_at             timestamptz NOT NULL DEFAULT now(),
    -- ARC-008 휴지통. NULL이면 휴지통에 없다. 영구 삭제는 행을 지운다
    deleted_at             timestamptz,

    UNIQUE (user_id, number),
    -- 본문 못 가져옴 이유는 blocked일 때만 있다. 다시 처리해 ready가 되면 이유도 지운다
    CHECK ((status = 'blocked') = (blocked_reason IS NOT NULL)),
    CHECK (kind <> 'link' OR (url IS NOT NULL AND normalized_url IS NOT NULL)),
    CHECK (kind <> 'text' OR text_body IS NOT NULL),
    CHECK (kind <> 'file' OR (object_path IS NOT NULL AND file_format IS NOT NULL AND content_hash IS NOT NULL))
);

-- COM-001: 같은 사용자 안에서만 같은 자료를 막는다. 휴지통 자료도 포함한다(규칙 7)
CREATE UNIQUE INDEX items_user_normalized_url_key ON items (user_id, normalized_url) WHERE normalized_url IS NOT NULL;
CREATE UNIQUE INDEX items_user_content_hash_key ON items (user_id, content_hash) WHERE content_hash IS NOT NULL;
CREATE UNIQUE INDEX items_user_idempotency_key ON items (user_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
-- `최근`: 휴지통 밖 자료를 최신순으로
CREATE INDEX items_user_recent_idx ON items (user_id, number DESC) WHERE deleted_at IS NULL;
CREATE INDEX items_search_idx ON items USING pgroonga (search_text);

-- POST /uploads가 만든 업로드 자리. POST /items {kind: file, uploadId}가 쓰면 consumed_at을 채운다.
-- 쓰이지 않은 자리와 그 객체는 청소 작업이 지운다.
CREATE TABLE uploads (
    id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    object_path   text        NOT NULL UNIQUE,
    file_name     text        NOT NULL,
    declared_size bigint      NOT NULL CHECK (declared_size >= 0),
    created_at    timestamptz NOT NULL DEFAULT now(),
    consumed_at   timestamptz
);

CREATE INDEX uploads_user_id_idx ON uploads (user_id);

-- 처리 작업 큐(ARC-005). 워커는 status = 'queued' AND run_at <= now()인 행을 FOR UPDATE SKIP LOCKED로 집는다.
-- 일시적 오류만 run_at을 미뤄 다시 넣는다(규칙 5). 영구 삭제는 CASCADE로 작업도 지운다.
-- 휴지통(deleted_at)으로 옮긴 자료는 행이 남으므로, 워커가 집을 때와 결과를 쓸 때 deleted_at을 보고 버린다(규칙 7)
CREATE TABLE item_jobs (
    id         bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    item_id    uuid        NOT NULL REFERENCES items (id) ON DELETE CASCADE,
    status     text        NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'running', 'done', 'failed')),
    attempts   integer     NOT NULL DEFAULT 0 CHECK (attempts >= 0),
    run_at     timestamptz NOT NULL DEFAULT now(),
    locked_at  timestamptz,
    last_error text,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX item_jobs_status_run_at_idx ON item_jobs (status, run_at);
-- 자료 하나에 기다리거나 도는 작업은 하나뿐이다. item_id 색인도 겸해 CASCADE 삭제가 표를 훑지 않는다
CREATE UNIQUE INDEX item_jobs_active_item_key ON item_jobs (item_id) WHERE status IN ('queued', 'running');
CREATE INDEX item_jobs_item_id_idx ON item_jobs (item_id);

ALTER TABLE items ENABLE ROW LEVEL SECURITY;
ALTER TABLE uploads ENABLE ROW LEVEL SECURITY;
ALTER TABLE item_jobs ENABLE ROW LEVEL SECURITY;
