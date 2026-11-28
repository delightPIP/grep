package com.unwrap.grep.features.account.adapters.http

import org.springframework.web.util.HtmlUtils

/**
 * 연결 승인 화면들(ARC-009 사용자 문구, 로그인은 ACC-001 문구). 서버가 그리는 작은 HTML이고 스크립트는 없다.
 * AI 도구 이름은 등록한 쪽이 정하므로 모든 값을 이스케이프한다.
 */
object ConsentPages {

	/** ACC-001 로그인 화면. [notice]는 `✗ 로그인 취소됨`·`✗ 로그인 실패: <이유>` 한 줄. */
	fun login(notice: String?): String = page(
		buildString {
			append(line("그렙 ~ $ 로그인 필요"))
			notice?.let { append(line(it, "notice")) }
			append("<div class=\"actions\">")
			append(link("/oauth/login?provider=google", "Google로 계속"))
			append(link("/oauth/login?provider=github", "GitHub로 계속"))
			append("</div>")
		},
	)

	/** ARC-009 연결 승인 화면. 처음 포커스는 첫 버튼(`허용`)이다(05 ST-24). */
	fun consent(client: String, account: String, requestId: String): String = page(
		buildString {
			append("<h1>그렙 연결</h1>")
			append(line("${client}가 그렙 계정 ${account}에 연결하려고 함"))
			append(line("이 도구는 보관함 전체를 검색하고 읽을 수 있음(읽기 전용). 읽어 간 내용은 그 도구 제공사의 정책을 따름"))
			append("<form method=\"post\" action=\"/oauth/decision\" class=\"actions\">")
			append("<input type=\"hidden\" name=\"request\" value=\"").append(escape(requestId)).append("\">")
			append("<button type=\"submit\" name=\"decision\" value=\"allow\" autofocus>허용</button>")
			append("<button type=\"submit\" name=\"decision\" value=\"deny\">거부</button>")
			append("</form>")
		},
	)

	/** 허용한 뒤. 잠깐 보인 뒤 AI 도구가 준 주소로 돌아간다. */
	fun allowed(client: String, redirect: String): String = page(
		line("✓ 연결됨  $client") + line("  이 창을 닫고 ${client}로 돌아가기"),
		redirect,
	)

	/** 거부한 뒤. AI 도구에 `access_denied`를 돌려준다. */
	fun denied(client: String, redirect: String): String = page(
		line("· 연결 안 함  $client") + line("  이 창을 닫아도 됨. 그렙 자료는 넘기기(복사)로 계속 쓸 수 있음"),
		redirect,
	)

	/** 정책에 문구가 없는 경우의 개발 제안 문구(PR에서 정책 반영을 묻는다). */
	fun expired(): String = page(line("! 연결 요청 만료 → AI 도구에서 다시 연결"))

	fun invalid(): String = page(line("✗ 연결할 수 없음: 잘못된 연결 요청"))

	private fun page(body: String, redirect: String? = null): String = buildString {
		append("<!doctype html><html lang=\"ko\"><head><meta charset=\"utf-8\">")
		append("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">")
		redirect?.let { append("<meta http-equiv=\"refresh\" content=\"1;url=").append(escape(it)).append("\">") }
		append("<title>그렙 연결</title><style>").append(STYLE).append("</style></head><body><main>")
		append(body)
		redirect?.let { append("<p class=\"line\"><a href=\"").append(escape(it)).append("\">→ 돌아가기</a></p>") }
		append("</main></body></html>")
	}

	private fun line(text: String, cssClass: String = "line") = "<p class=\"$cssClass\">${escape(text)}</p>"

	private fun link(href: String, text: String) = "<a class=\"button\" href=\"${escape(href)}\">${escape(text)}</a>"

	private fun escape(value: String): String = HtmlUtils.htmlEscape(value, "UTF-8")

	private const val STYLE = """
		:root{color-scheme:light dark;--bg:#fbfaf7;--fg:#1d1c1a;--muted:#6b675f;--line:#d9d5cc}
		@media (prefers-color-scheme:dark){:root{--bg:#161513;--fg:#ecebe6;--muted:#9a968d;--line:#3a3833}}
		body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.6 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}
		main{max-width:560px;margin:15vh auto;padding:0 16px}
		h1{font-size:15px;margin:0 0 12px}
		.line{margin:0 0 8px;white-space:pre-wrap}
		.notice{margin:0 0 8px;color:var(--muted)}
		.actions{display:flex;gap:12px;margin-top:20px}
		.button,button{font:inherit;color:var(--fg);background:none;border:1px solid var(--line);padding:6px 14px;text-decoration:none;cursor:pointer}
		.button:focus-visible,button:focus-visible{outline:2px solid var(--fg);outline-offset:2px}
		a{color:var(--fg)}
	"""
}
