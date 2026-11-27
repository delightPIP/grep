-- 뜻이 가까운 찾기(F15, ADR-BCK-016, #128). Gemini 임베딩을 768차원으로 줄여 둔다.
-- 임베딩은 요약이 끝난(ready) 자료에 따로 만든다. 하루 한도(COM-005와 따로 셈)는 embedding_attempted_at으로 센다.
-- shortcut: 사용자별 자료 수가 적어 벡터 인덱스 없이 user_id로 좁힌 뒤 거리순으로 본다. 자료가 수천 건을 넘으면 HNSW 인덱스를 더한다.
CREATE EXTENSION IF NOT EXISTS vector;

ALTER TABLE items ADD COLUMN embedding vector(768);
-- 임베딩을 만든 모델(ADR-BCK-008의 summary_model과 같은 쓰임)
ALTER TABLE items ADD COLUMN embedding_model text;
-- 마지막으로 임베딩을 부른 시각. 실패하면 이 시각에서 한 시간 뒤에 다시 부른다
ALTER TABLE items ADD COLUMN embedding_attempted_at timestamptz;
