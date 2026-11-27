-- #93 정리 기능 계약: 휴지통(ARC-008), 고치기(ARC-002·004), 샘플(ARC-010), 측정 이벤트(D-08).
-- 로그아웃 모든기기(ACC-002)는 클라이언트가 Supabase 전역 로그아웃으로 갱신 토큰을 끊는다. 서버 표는 바꾸지 않는다(AI 도구 연결 끊기는 F7 계약에서).
-- 휴지통은 V2의 items.deleted_at을 쓴다(NULL이 아니면 휴지통). 영구 삭제는 행을 지운다(번호는 users.last_item_number가 막아 다시 쓰지 않는다).

-- 고치기: 직접 고친 제목. 있으면 처리 워커가 가져온 제목보다 우선하고, 워커는 덮어쓰지 않는다.
-- 직접 고친 요약은 V2의 items.user_summary다.
ALTER TABLE items ADD COLUMN user_title text;
-- 지운 태그(`#` 없이). 처리 워커가 태그를 만들 때 이 목록은 다시 붙이지 않는다(ARC-002 규칙 2)
ALTER TABLE items ADD COLUMN removed_tags text[] NOT NULL DEFAULT '{}';

-- 30일 자동 삭제 작업이 휴지통 자료만 훑는다(ARC-008 규칙 7)
CREATE INDEX items_trashed_idx ON items (deleted_at) WHERE deleted_at IS NOT NULL;

-- 샘플을 받은 범위. 두 번 눌러도 한 번만 저장하고 처음 범위를 돌려준다(ARC-010 규칙 7)
ALTER TABLE users ADD COLUMN sample_first_number bigint;
ALTER TABLE users ADD COLUMN sample_last_number bigint;
ALTER TABLE users ADD CONSTRAINT users_sample_range_check
    CHECK ((sample_first_number IS NULL) = (sample_last_number IS NULL)
           AND (sample_first_number IS NULL OR sample_last_number = sample_first_number + 7));

-- 측정 이벤트(PRD 4절, 05 6-5절 D-08). 제목·본문·검색어·파일 이름·주소·자료 번호는 넣지 않는다.
-- day_kst: 한국 시간 날짜. item_count: 저장·넘긴 건수. days_since_saved: 넘긴(읽은) 자료마다 저장 뒤 지난 일수
CREATE TABLE events (
    id               bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id          uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    name             text        NOT NULL CHECK (name IN ('item_saved', 'handoff_copied', 'connection_read')),
    method           text,
    item_count       integer     NOT NULL DEFAULT 1 CHECK (item_count >= 0),
    days_since_saved integer[]   NOT NULL DEFAULT '{}',
    day_kst          date        NOT NULL,
    created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX events_name_day_idx ON events (name, day_kst);
CREATE INDEX events_user_id_idx ON events (user_id);

ALTER TABLE events ENABLE ROW LEVEL SECURITY;
