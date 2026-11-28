package com.unwrap.grep.features.archive.item.adapters.storage

import com.sun.net.httpserver.HttpServer
import com.unwrap.grep.features.archive.item.domain.StoredObject
import java.net.InetSocketAddress
import java.time.Duration
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * 서명은 네트워크 없이 계산된다. 읽기는 로컬 서버를 S3 경로 방식 엔드포인트처럼 세워 본다.
 * 실제 Supabase Storage 연결은 키를 받은 뒤 확인한다(#55).
 */
class S3ObjectStorageTest {
	private var server: HttpServer? = null

	@AfterTest
	fun stop() {
		server?.stop(0)
	}

	/** `/items/<key>` GET에 답하는 서버. [chunked]면 Content-Length 없이 보낸다. */
	private fun storageWith(objects: Map<String, ByteArray>, chunked: Boolean = false): S3ObjectStorage {
		val started = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
		started.createContext("/items/") { exchange ->
			val body = objects[exchange.requestURI.path.removePrefix("/items/")]
			if (body == null) {
				val xml = "<Error><Code>NoSuchKey</Code><Message>no</Message></Error>".toByteArray()
				exchange.responseHeaders.add("Content-Type", "application/xml")
				exchange.sendResponseHeaders(404, xml.size.toLong())
				exchange.responseBody.use { it.write(xml) }
				return@createContext
			}
			exchange.responseHeaders.add("Content-Type", "application/octet-stream")
			exchange.sendResponseHeaders(200, if (chunked) 0 else body.size.toLong())
			runCatching { exchange.responseBody.use { it.write(body) } }
		}
		started.start()
		server = started
		return S3ObjectStorage("http://127.0.0.1:${started.address.port}", "", "key", "secret", "items")
	}

	@Test
	fun `상한안의객체일때_읽으면_내용을주고없으면null인지`() {
		// given
		val storage = storageWith(mapOf("u/a" to "안녕".toByteArray()))

		// when
		val found = storage.read("u/a", 100)
		val missing = storage.read("u/none", 100)

		// then
		assertEquals("안녕", String((found as StoredObject.Content).bytes))
		assertNull(missing)
	}

	@Test
	fun `객체가상한보다클때_읽으면_다받지않고크기만주는지`() {
		// given
		val big = ByteArray(5_000) { 1 }
		val declared = storageWith(mapOf("u/big" to big))

		// when
		val result = declared.read("u/big", 1_000)

		// then
		assertEquals(StoredObject.TooLarge(5_000), result)
	}

	@Test
	fun `크기를알리지않는큰객체일때_읽으면_상한다음바이트에서멈추고크다고하는지`() {
		// given
		val storage = storageWith(mapOf("u/big" to ByteArray(5_000) { 1 }), chunked = true)

		// when
		val result = storage.read("u/big", 1_000)

		// then
		assertTrue(result is StoredObject.TooLarge && result.size > 1_000, result.toString())
	}

	@Test
	fun `키와엔드포인트가있을때_서명PUT주소를만들면_경로방식주소에서명과만료가붙는지`() {
		// given
		val storage = S3ObjectStorage(
			endpoint = "https://project.supabase.co/storage/v1/s3",
			region = "",
			accessKeyId = "test-access-key",
			secretAccessKey = "test-secret",
			bucket = "items",
		)

		// when
		val url = storage.presignPut("user-1/upload-1", Duration.ofMinutes(15))

		// then
		assertEquals("project.supabase.co", url.host)
		assertEquals("/storage/v1/s3/items/user-1/upload-1", url.path)
		assertTrue(url.query.contains("X-Amz-Signature="))
		assertTrue(url.query.contains("X-Amz-Expires=900"))
	}
}
