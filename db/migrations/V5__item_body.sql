-- 자세히 보기(ARC-011)와 AI 도구 읽기(ARC-009)의 본문. 처리 워커가 읽은 본문을 남긴다(#131, 통합 승인).
-- 글 자료는 text_body가 곧 본문이라 여기 두지 않는다. 처리 전이거나 이 열 전에 처리한 자료는 null이다.
-- 잘림 여부는 body_length > char_length(body_text)로 판정한다.
ALTER TABLE items ADD COLUMN body_text text;
ALTER TABLE items ADD COLUMN body_length integer CHECK (body_length >= 0);
ALTER TABLE items ADD COLUMN body_from_image boolean NOT NULL DEFAULT false;
