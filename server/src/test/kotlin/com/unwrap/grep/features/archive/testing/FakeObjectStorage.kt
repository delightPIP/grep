package com.unwrap.grep.features.archive.testing

import com.unwrap.grep.features.archive.domain.ObjectStorage
import com.unwrap.grep.features.archive.domain.StoredObject
import org.springframework.boot.test.context.TestConfiguration
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Primary
import java.net.URI
import java.time.Duration
import java.util.concurrent.ConcurrentHashMap

/** 메모리 스토리지. 클라이언트의 서명 URL PUT도 [put]으로 흉내 낸다. */
class FakeObjectStorage : ObjectStorage {
	private val objects = ConcurrentHashMap<String, ByteArray>()
	private val contentTypes = ConcurrentHashMap<String, String>()

	override fun put(objectPath: String, bytes: ByteArray, contentType: String) {
		objects[objectPath] = bytes
		contentTypes[objectPath] = contentType
	}

	fun contentTypeOf(objectPath: String): String? = contentTypes[objectPath]

	fun exists(objectPath: String): Boolean = objects.containsKey(objectPath)

	override fun presignPut(objectPath: String, expiresIn: Duration): URI =
		URI("https://storage.test/items/$objectPath?expires=${expiresIn.seconds}")

	override fun read(objectPath: String, maxBytes: Long): StoredObject? {
		val bytes = objects[objectPath] ?: return null
		return if (bytes.size > maxBytes) StoredObject.TooLarge(bytes.size.toLong()) else StoredObject.Content(bytes)
	}

	override fun delete(objectPath: String) {
		objects.remove(objectPath)
		contentTypes.remove(objectPath)
	}
}

@TestConfiguration(proxyBeanMethods = false)
class FakeObjectStorageConfiguration {
	@Bean
	@Primary
	fun fakeObjectStorage(): FakeObjectStorage = FakeObjectStorage()
}
