-- 가져온 자료도 뒤에서 요약한다(ADR-BCK-017, ADR-BCK-008 결정 2 대체, #127 후속).
-- 처리 작업에 우선순위를 둔다. 0 = 보통(직접 저장), 1 = 낮음(가져오기). 워커는 보통부터 집는다.
-- 낮은 작업은 그날 "하루 한도 - 직접 저장 몫"까지만 집고, 열기·넘기기 때 보통으로 올린다.
ALTER TABLE item_jobs ADD COLUMN priority smallint NOT NULL DEFAULT 0 CHECK (priority IN (0, 1));

DROP INDEX item_jobs_status_run_at_idx;
CREATE INDEX item_jobs_claim_idx ON item_jobs (status, priority, run_at);

-- items.processing_deferred(V4)는 더 쓰지 않는다. 열은 다음 정리 때 지운다.
-- 이미 가져와 작업 없이 미뤄 둔 자료에 낮은 우선순위 작업을 만든다.
INSERT INTO item_jobs (item_id, priority)
SELECT i.id, 1 FROM items i
WHERE i.processing_deferred AND i.deleted_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM item_jobs j WHERE j.item_id = i.id);

UPDATE items SET processing_deferred = false WHERE processing_deferred;
