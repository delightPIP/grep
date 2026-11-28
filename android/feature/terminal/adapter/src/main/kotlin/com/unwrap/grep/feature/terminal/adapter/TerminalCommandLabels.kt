package com.unwrap.grep.feature.terminal.adapter

internal fun commandLabel(command: String): String = when (command) {
    "keep" -> "담기"
    "recent" -> "최근"
    "seek" -> "찾기"
    "pick" -> "고르기"
    "handoff" -> "넘기기"
    "guide" -> "도움말"
    "about" -> "설명"
    "signOut" -> "로그아웃"
    "revise" -> "고치기"
    "drop" -> "버리기"
    "revive" -> "되살리기"
    "bin" -> "휴지통"
    "pack" -> "묶음"
    "peek" -> "열기"
    "gather" -> "찾아두기"
    "bring" -> "가져오기"
    "plug" -> "연결"
    else -> command
}

internal fun commandFailureLabel(failure: String): String = when (failure) {
    "disconnected" -> "연결 끊김"
    "timedOut" -> "응답 없음"
    "serverError" -> "서버 오류"
    "clipboardDenied" -> "클립보드 거부"
    else -> "오류"
}

internal fun aboutDescription(command: String): String = when (command) {
    "keep" -> "링크나 글, 파일을 저장한다. 예: 담기 https://…"
    "recent" -> "최근 저장한 자료 목록을 본다."
    "seek" -> "검색어와 #태그로 자료를 찾는다. 예: 찾기 결제 #웹훅"
    "pick" -> "번호로 넘길 자료를 고른다. 예: 고르기 131 140"
    "handoff" -> "고른 자료를 AI 도구에 붙여 넣을 글로 복사한다."
    "guide" -> "명령 목록을 본다."
    "about" -> "명령 하나를 설명한다. 예: 설명 찾기"
    "signOut" -> "이 기기에서 로그아웃한다."
    "revise" -> "자료의 제목·요약을 고친다. 예: 고치기 131"
    "drop" -> "자료를 휴지통으로 보낸다. 예: 버리기 131"
    "revive" -> "휴지통 자료를 되살린다. 예: 되살리기 131"
    "bin" -> "휴지통 목록을 본다."
    else -> ""
}
