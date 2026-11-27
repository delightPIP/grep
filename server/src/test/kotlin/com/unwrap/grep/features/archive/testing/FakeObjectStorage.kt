package com.unwrap.grep.features.archive.testing

import com.unwrap.grep.features.archive.domain.ObjectStorage
import com.unwrap.grep.features.archive.domain.StoredObject
import org.springframework.boot.test.context.TestConfiguration
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Primary
import java.net.URI
import java.time.Duration
import java.util.concurrent.ConcurrentHashMap

/** 메모리 스토리지. 클라이언트의 서명 URL PUT은 [put]으로 흉내 낸다. */
class FakeObjectStorage : ObjectStorage {
	private val objects = ConcurrentHashMap<String, ByteArray>()

	fun put(objectPath: String, bytes: ByteArray) {
		objects[objectPath] = bytes
	}

	fun exists(objectPath: String): Boolean = objects.containsKey(objectPath)

	override fun presignPut(objectPath: String, expiresIn: Duration): URI =
		URI("https://storage.test/items/$objectPath?expires=${expiresIn.seconds}")

	override fun read(objectPath: String, maxBytes: Long): StoredObject? {
		val bytes = objects[objectPath] ?: return null
		return if (bytes.size > maxBytes) StoredObject.TooLarge(bytes.size.toLong()) else StoredObject.Content(bytes)
	}

	override fun delete(objectPath: String) {
		objects.remove(objectPath)
	}
}

@TestConfiguration(proxyBeanMethods = false)
class FakeObjectStorageConfiguration {
	@Bean
	@Primary
	fun fakeObjectStorage(): FakeObjectStorage = FakeObjectStorage()
}
