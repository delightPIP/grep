package com.unwrap.grep.features.archive.transfer.adapters.http

import com.unwrap.grep.features.archive.item.adapters.http.parseUuid
import com.unwrap.grep.features.archive.transfer.domain.BookmarkImportService
import com.unwrap.grep.features.archive.transfer.domain.ImportStatus
import com.unwrap.grep.shared.kernel.ApiProblem
import com.unwrap.grep.shared.kernel.CURRENT_USER_ID
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestAttribute
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.ResponseStatus
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

/** openapi `ImportRequest`. */
data class ImportRequest(val html: String?)

/** 북마크 가져오기(F8): POST /imports(startImport), GET /imports/{id}(getImport). */
@RestController
class ImportsController(private val imports: BookmarkImportService) {

	@PostMapping("/imports")
	@ResponseStatus(HttpStatus.ACCEPTED)
	fun start(@RequestAttribute(CURRENT_USER_ID) userId: UUID, @RequestBody request: ImportRequest): ImportStatus =
		imports.start(userId, request.html ?: throw ApiProblem.invalidRequest("html is required"))

	@GetMapping("/imports/{id}")
	fun status(@RequestAttribute(CURRENT_USER_ID) userId: UUID, @PathVariable id: String): ImportStatus =
		imports.status(userId, parseUuid(id) ?: throw ApiProblem.invalidRequest("id must be a UUID"))
}
