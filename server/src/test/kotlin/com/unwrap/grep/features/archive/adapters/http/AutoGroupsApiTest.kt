package com.unwrap.grep.features.archive.adapters.http

import com.unwrap.grep.features.archive.testing.ArchiveApiTestSupport
import com.unwrap.grep.features.archive.testing.SearchRow
import com.unwrap.grep.features.archive.testing.insertSearchRow
import org.hamcrest.Matchers.contains
import org.springframework.test.web.servlet.get
import java.time.LocalDate
import java.time.ZoneId
import kotlin.test.Test

/** GET /groups(listAutoGroups)와 GET /items의 kind·source·tag. 근거: ARC-007 규칙 2·6·7·8·9와 값, COM-006. */
class AutoGroupsApiTest : ArchiveApiTestSupport() {

	private fun groups(token: String, vararg params: Pair<String, String>) = mockMvc.get("/groups") {
		header("Authorization", "Bearer $token")
		params.forEach { (name, value) -> param(name, value) }
	}

	private fun newUserWith(vararg rows: SearchRow): String {
		val token = newUser()
		val userId = userIdOf(token)
		rows.forEach { jdbc.insertSearchRow(userId, it) }
		return token
	}

	private fun savedDaysAgo(token: String, number: Long, days: Long) {
		jdbc.sql("UPDATE items SET created_at = now() - make_interval(days => CAST(:days AS integer)) WHERE user_id = :userId AND number = :number")
			.param("days", days).param("userId", userIdOf(token)).param("number", number).update()
	}

	private val mixed = arrayOf(
		SearchRow(1, "link", "결제", "결제", tags = listOf("결제", "위젯"), source = "toss.im"),
		SearchRow(2, "link", "위젯", "위젯", tags = listOf("위젯"), source = "toss.im"),
		SearchRow(3, "link", "블로그", "블로그", source = "blog.example.com"),
		SearchRow(4, "text", "메모", "메모"),
		SearchRow(5, "file", "포스터", "포스터", fileFormat = "png", source = "png"),
		SearchRow(6, "file", "보고서", "보고서", fileFormat = "pdf", source = "pdf"),
		SearchRow(7, "link", "버린 것", "버린 것", tags = listOf("휴지통"), source = "trash.example", inTrash = true),
	)

	@Test
	fun `여러형식출처태그가섞였을때_자동묶음을부르면_0건과휴지통을빼고건수를주는지`() {
		// given
		val token = newUserWith(*mixed)

		// when
		val result = groups(token)

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.kinds[*].key") { value(contains("link", "text", "image", "file")) }
			jsonPath("$.kinds[*].count") { value(contains(3, 1, 1, 1)) }
			jsonPath("$.sources[*].key") { value(contains("direct", "toss.im", "blog.example.com")) }
			jsonPath("$.sources[*].count") { value(contains(3, 2, 1)) }
			jsonPath("$.tags[*].key") { value(contains("위젯", "결제")) }
			jsonPath("$.tags[*].count") { value(contains(2, 1)) }
		}
	}

	@Test
	fun `저장시점이다를때_자동묶음을부르면_오늘이번주이번달그전을시작시각이상으로세고0건은빼는지`() {
		// given
		val token = newUserWith(*mixed.take(3).toTypedArray())
		val today = LocalDate.now(ZoneId.of("Asia/Seoul"))
		val monthStart = today.withDayOfMonth(1)
		savedDaysAgo(token, 3, today.toEpochDay() - monthStart.toEpochDay() + 40)

		// when
		val result = groups(token, "tz" to "Asia/Seoul")

		// then
		result.andExpect {
			status { isOk() }
			jsonPath("$.periods[0].key") { value("today") }
			jsonPath("$.periods[0].count") { value(2) }
			jsonPath("$.periods[?(@.key == 'thisWeek')].count") { value(contains(2)) }
			jsonPath("$.periods[?(@.key == 'thisMonth')].count") { value(contains(2)) }
			jsonPath("$.periods[?(@.key == 'earlier')].count") { value(contains(1)) }
		}
	}

	@Test
	fun `잘못된시간대일때_자동묶음을부르면_400invalid_request인지`() {
		// given
		val token = newUser()

		// when
		val result = groups(token, "tz" to "Mars/Base")

		// then
		result.andExpect {
			status { isBadRequest() }
			jsonPath("$.code") { value("invalid_request") }
		}
	}

	@Test
	fun `형식출처태그로거를때_최근을부르면_그묶음자료만번호큰순으로주는지`() {
		// given
		val token = newUserWith(*mixed)

		// when
		val images = listItems(token, "kind" to "image")
		val files = listItems(token, "kind" to "file")
		val direct = listItems(token, "source" to "direct")
		val toss = listItems(token, "source" to "toss.im", "tag" to "결제")

		// then
		images.andExpect { jsonPath("$.items[*].number") { value(contains(5)) } }
		files.andExpect { jsonPath("$.items[*].number") { value(contains(6)) } }
		direct.andExpect { jsonPath("$.items[*].number") { value(contains(6, 5, 4)) } }
		toss.andExpect { jsonPath("$.items[*].number") { value(contains(1)) } }
	}

	@Test
	fun `없는형식이거나빈출처일때_최근을부르면_400인지`() {
		// given
		val token = newUser()

		// when
		val badKind = listItems(token, "kind" to "video")
		val blankSource = listItems(token, "source" to " ")

		// then
		badKind.andExpect { status { isBadRequest() } }
		blankSource.andExpect { status { isBadRequest() } }
	}
}
