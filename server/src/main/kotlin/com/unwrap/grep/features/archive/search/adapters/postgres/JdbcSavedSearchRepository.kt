package com.unwrap.grep.features.archive.search.adapters.postgres

import com.unwrap.grep.features.archive.search.domain.SavedSearchRepository
import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.stereotype.Repository
import java.util.UUID

/** saved_searches(V4). query는 공백 정리한 검색어이고 (user_id, query)가 유일하다. */
@Repository
class JdbcSavedSearchRepository(private val jdbc: JdbcClient) : SavedSearchRepository {

	/** 두 기기가 동시에 같은 검색어를 찾아둬도 유일 제약으로 하나만 남는다. */
	override fun insertIfAbsent(userId: UUID, query: String): Boolean =
		jdbc.sql("INSERT INTO saved_searches (user_id, query) VALUES (:userId, :query) ON CONFLICT (user_id, query) DO NOTHING")
			.param("userId", userId)
			.param("query", query)
			.update() == 1

	override fun queries(userId: UUID): List<String> =
		jdbc.sql("SELECT query FROM saved_searches WHERE user_id = :userId ORDER BY created_at DESC, id")
			.param("userId", userId)
			.query { rs, _ -> rs.getString("query") }
			.list()

	override fun delete(userId: UUID, query: String): Boolean =
		jdbc.sql("DELETE FROM saved_searches WHERE user_id = :userId AND query = :query")
			.param("userId", userId)
			.param("query", query)
			.update() > 0
}
