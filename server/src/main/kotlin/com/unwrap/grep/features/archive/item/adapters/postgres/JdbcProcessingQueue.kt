package com.unwrap.grep.features.archive.item.adapters.postgres

import com.unwrap.grep.features.archive.api.ItemOriginals
import com.unwrap.grep.features.archive.api.LowPriorityGate
import com.unwrap.grep.features.archive.api.ProcessingJob
import com.unwrap.grep.features.archive.api.ProcessingOutcome
import com.unwrap.grep.features.archive.api.ProcessingQueue
import com.unwrap.grep.features.archive.item.domain.ObjectStorage
import com.unwrap.grep.features.archive.item.domain.StoredObject
import org.springframework.jdbc.core.RowMapper
import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.stereotype.Repository
import org.springframework.transaction.support.TransactionTemplate
import java.sql.Timestamp
import java.sql.Types
import java.time.Duration
import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

/** item_jobs 큐(V2 주석)와 처리 결과 쓰기. 결과는 휴지통 밖 자료에만 쓴다(ARC-005 규칙 7). */
@Repository
class JdbcProcessingQueue(
	private val jdbc: JdbcClient,
	private val transaction: TransactionTemplate,
	private val storage: ObjectStorage,
) : ProcessingQueue, ItemOriginals {

	override fun claimNext(lease: Duration, lowPriorityGate: LowPriorityGate?): ProcessingJob? = transaction.execute {
		jdbc.sql(
			"""
			WITH picked AS (
				SELECT q.id FROM item_jobs q
				WHERE ((q.status = 'queued' AND q.run_at <= now())
				       OR (q.status = 'running' AND q.locked_at < now() - make_interval(secs => :leaseSeconds)))
				  AND (q.priority = 0 OR CAST(:maxLowClaims AS integer) IS NULL OR (
				      SELECT count(*) FROM item_jobs c JOIN items ci ON ci.id = c.item_id
				      WHERE ci.user_id = (SELECT qi.user_id FROM items qi WHERE qi.id = q.item_id)
				        AND c.locked_at >= CAST(:dayStart AS timestamptz)
				  ) < CAST(:maxLowClaims AS integer))
				ORDER BY q.priority, q.run_at
				LIMIT 1
				FOR UPDATE OF q SKIP LOCKED
			), claimed AS (
				UPDATE item_jobs j SET status = 'running', locked_at = now(), attempts = j.attempts + 1
				FROM picked WHERE j.id = picked.id
				RETURNING j.id, j.item_id, j.attempts
			), marked AS (
				UPDATE items i SET status = 'processing', updated_at = now()
				FROM claimed WHERE i.id = claimed.item_id AND i.deleted_at IS NULL
			)
			SELECT c.id AS job_id, c.attempts, i.user_id, i.deleted_at, i.kind, i.title, i.source, i.url, i.text_body,
			       i.object_path, i.file_format
			FROM claimed c JOIN items i ON i.id = c.item_id
			""".trimIndent(),
		)
			.param("leaseSeconds", lease.seconds)
			.param("maxLowClaims", lowPriorityGate?.maxClaims, Types.INTEGER)
			.param("dayStart", lowPriorityGate?.dayStart?.let { OffsetDateTime.ofInstant(it, ZoneOffset.UTC) }, Types.TIMESTAMP_WITH_TIMEZONE)
			.query(JOB_ROW)
			.optional()
			.orElse(null)
	}

	/** shortcut: 하루 처리 수를 따로 기록하는 표가 없어(계약 변경은 #56) 그날 집힌 작업 수로 센다. 본문을 못 가져온 자료도 1건으로 센다. */
	override fun countClaimedSince(userId: UUID, since: Instant): Int =
		jdbc.sql(
			"""
			SELECT count(*) FROM item_jobs j JOIN items i ON i.id = j.item_id
			WHERE i.user_id = :userId AND j.locked_at >= :since
			""".trimIndent(),
		)
			.param("userId", userId)
			.param("since", Timestamp.from(since))
			.query(Int::class.java)
			.single()

	override fun finish(job: ProcessingJob, outcome: ProcessingOutcome): Boolean =
		transaction.execute {
			val written = writeItem(job.jobId, outcome)
			val jobStatus = if (outcome is ProcessingOutcome.Failed) "failed" else "done"
			val error = (outcome as? ProcessingOutcome.Failed)?.error
			endJob(job.jobId, if (written) jobStatus else "done", if (written) error else "discarded: in trash")
			written
		} ?: false

	override fun discard(job: ProcessingJob) {
		endJob(job.jobId, "done", "discarded: in trash")
	}

	override fun retryLater(job: ProcessingJob, delay: Duration, error: String) {
		jdbc.sql(
			"""
			UPDATE item_jobs SET status = 'queued', run_at = now() + make_interval(secs => :delaySeconds), locked_at = NULL,
			                     last_error = :error
			WHERE id = :id
			""".trimIndent(),
		)
			.param("delaySeconds", delay.seconds)
			.param("error", error)
			.param("id", job.jobId)
			.update()
	}

	override fun read(objectPath: String, maxBytes: Long): ByteArray? =
		(storage.read(objectPath, maxBytes) as? StoredObject.Content)?.bytes

	/**
	 * 링크 제목은 아직 주소 그대로이고 직접 고치지 않았을 때만 가져온 제목으로 바꾼다(V3 user_title).
	 * 직접 고친 요약(user_summary)은 쓰지 않고, 사용자가 지운 태그(V3 removed_tags)는 다시 붙이지 않는다(ARC-002 규칙 2).
	 * search_text는 제목·출처·요약·태그·본문 일부를 다시 모은다(V2 주석).
	 */
	private fun writeItem(jobId: Long, outcome: ProcessingOutcome): Boolean {
		val ready = outcome as? ProcessingOutcome.Ready
		val (status, blockedReason) = when (outcome) {
			is ProcessingOutcome.Ready -> "ready" to null
			is ProcessingOutcome.Blocked -> "blocked" to outcome.reason
			is ProcessingOutcome.Failed -> "failed" to null
		}
		return jdbc.sql(
			"""
			UPDATE items i SET
				status = :status,
				blocked_reason = :blockedReason,
				title = CASE WHEN i.kind = 'link' AND i.user_title IS NULL AND i.title = i.url AND CAST(:fetchedTitle AS text) IS NOT NULL
				             THEN :fetchedTitle ELSE i.title END,
				list_summary = :listSummary,
				handoff_summary = :handoffSummary,
				partial_note = :partialNote,
				tags = ARRAY(
					SELECT t FROM unnest(CAST(:tags AS text[])) WITH ORDINALITY AS u(t, o)
					WHERE lower(t) <> ALL(i.removed_tags) ORDER BY o
				),
				summary_model = :model,
				summary_prompt_version = :promptVersion,
				search_text = concat_ws(' ',
					CASE WHEN i.kind = 'link' AND i.user_title IS NULL AND i.title = i.url AND CAST(:fetchedTitle AS text) IS NOT NULL
					     THEN :fetchedTitle ELSE i.title END,
					i.source, i.user_summary, :listSummary, :handoffSummary, array_to_string(ARRAY(
						SELECT t FROM unnest(CAST(:tags AS text[])) AS u(t) WHERE lower(t) <> ALL(i.removed_tags)
					), ' '), :searchBody),
				body_text = :bodyText,
				body_length = :bodyLength,
				body_from_image = :bodyFromImage,
				updated_at = now()
			FROM item_jobs j
			WHERE j.id = :jobId AND i.id = j.item_id AND i.deleted_at IS NULL
			""".trimIndent(),
		)
			.param("status", status)
			.param("blockedReason", blockedReason, Types.VARCHAR)
			.param("fetchedTitle", ready?.fetchedTitle, Types.VARCHAR)
			.param("listSummary", ready?.listSummary, Types.VARCHAR)
			.param("handoffSummary", ready?.handoffSummary, Types.VARCHAR)
			.param("partialNote", ready?.partialNote, Types.VARCHAR)
			.param("tags", ready?.tags.orEmpty().toTypedArray())
			.param("model", ready?.model, Types.VARCHAR)
			.param("promptVersion", ready?.promptVersion, Types.VARCHAR)
			.param("searchBody", outcome.searchBody, Types.VARCHAR)
			.param("bodyText", outcome.body?.text, Types.VARCHAR)
			.param("bodyLength", outcome.body?.length, Types.INTEGER)
			.param("bodyFromImage", outcome.body?.fromImage ?: false)
			.param("jobId", jobId)
			.update() == 1
	}

	/** locked_at은 지우지 않는다. 그날 집힌 작업 수(하루 한도, COM-005·ADR-BCK-017)를 이 시각으로 센다. 임대 만료는 running일 때만 본다. */
	private fun endJob(jobId: Long, status: String, error: String?) {
		jdbc.sql("UPDATE item_jobs SET status = :status, last_error = :error WHERE id = :id")
			.param("status", status)
			.param("error", error, Types.VARCHAR)
			.param("id", jobId)
			.update()
	}

	private companion object {
		val JOB_ROW = RowMapper { rs, _ ->
			ProcessingJob(
				jobId = rs.getLong("job_id"),
				userId = rs.getObject("user_id", UUID::class.java),
				attempts = rs.getInt("attempts"),
				inTrash = rs.getObject("deleted_at") != null,
				kind = rs.getString("kind"),
				title = rs.getString("title"),
				source = rs.getString("source"),
				url = rs.getString("url"),
				textBody = rs.getString("text_body"),
				objectPath = rs.getString("object_path"),
				fileFormat = rs.getString("file_format"),
			)
		}
	}
}
