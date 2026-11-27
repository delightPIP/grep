package com.unwrap.grep.features.archive.adapters.storage

import java.time.Duration
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** 서명은 네트워크 없이 계산된다. 실제 Supabase Storage 연결은 키를 받은 뒤 확인한다(#55). */
class S3ObjectStorageTest {

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
