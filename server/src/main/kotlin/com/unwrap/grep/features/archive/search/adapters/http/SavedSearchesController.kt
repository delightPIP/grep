package com.unwrap.grep.features.archive.search.adapters.http

import com.unwrap.grep.features.archive.search.domain.SavedSearch
import com.unwrap.grep.features.archive.search.domain.SavedSearchService
import com.unwrap.grep.shared.kernel.ApiProblem
import com.unwrap.grep.shared.kernel.CURRENT_USER_ID
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestAttribute
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.ResponseStatus
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

/** openapi `SavedSearchRequest`. */
data class SavedSearchRequest(val query: String?)

/** openapi `SavedSearchList`. */
data class SavedSearchListResponse(val searches: List<SavedSearch>)

/** 찾아두기(ARC-012): GET·PUT·DELETE /saved-searches. */
@RestController
class SavedSearchesController(private val searches: SavedSearchService) {

	@GetMapping("/saved-searches")
	fun list(@RequestAttribute(CURRENT_USER_ID) userId: UUID) = SavedSearchListResponse(searches.list(userId))

	/** 새로 만들면 201, 이미 있으면 200(`! 이미 찾아둠`). */
	@PutMapping("/saved-searches")
	fun save(@RequestAttribute(CURRENT_USER_ID) userId: UUID, @RequestBody request: SavedSearchRequest): ResponseEntity<SavedSearch> {
		val saved = searches.save(userId, request.query ?: throw ApiProblem.invalidRequest("query is required"))
		return ResponseEntity.status(if (saved.created) HttpStatus.CREATED else HttpStatus.OK).body(saved.search)
	}

	@DeleteMapping("/saved-searches")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	fun delete(@RequestAttribute(CURRENT_USER_ID) userId: UUID, @RequestParam(required = false) query: String?) =
		searches.delete(userId, query ?: throw ApiProblem.invalidRequest("query is required"))
}
