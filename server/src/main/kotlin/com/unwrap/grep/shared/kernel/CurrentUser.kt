package com.unwrap.grep.shared.kernel

/**
 * 인증 필터가 검증된 토큰에서 찾은 사용자 ID(UUID)를 넣는 요청 속성 이름.
 * 기능 모듈은 사용자 ID를 요청 본문이 아니라 여기서만 읽는다(COM-006 규칙 1).
 */
const val CURRENT_USER_ID = "grep.currentUserId"
