-- 새 Supabase 프로젝트를 흉내 낸다. "RLS 자동 켜기" 옵션이 public 스키마에 함수를 미리 만든다(AI 로그 081 발견 사항 2).
CREATE FUNCTION public.rls_auto_enable() RETURNS void LANGUAGE sql AS 'SELECT';
