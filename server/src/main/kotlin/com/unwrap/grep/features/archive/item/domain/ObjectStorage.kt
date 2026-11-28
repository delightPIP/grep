package com.unwrap.grep.features.archive.item.domain

import java.net.URI
import java.time.Duration

/** 파일 원본 저장소(ADR-BCK-002 결정 2). 실제 구현은 S3 호환 스토리지, 테스트는 가짜다. */
interface ObjectStorage {
	/** 클라이언트가 원본을 직접 올릴 서명 PUT URL. */
	fun presignPut(objectPath: String, expiresIn: Duration): URI

	/** 원본을 여는 서명 GET URL(자세히 보기 `원본 열기`·이미지 미리보기, ARC-011). 객체가 있는지는 보지 않는다. */
	fun presignGet(objectPath: String, expiresIn: Duration): URI

	/** 서버가 원본을 직접 올린다. 데모 시드 도구(#69)만 쓴다. 같은 경로면 덮어쓴다. 버킷이 허용 형식을 걸어 두면 [contentType]이 맞아야 한다. */
	fun put(objectPath: String, bytes: ByteArray, contentType: String)

	/** 객체가 없으면 null. [maxBytes]를 넘으면 내용을 읽지 않고 크기만 준다. */
	fun read(objectPath: String, maxBytes: Long): StoredObject?

	/** 없는 객체를 지워도 오류가 아니다. */
	fun delete(objectPath: String)
}

sealed interface StoredObject {
	class Content(val bytes: ByteArray) : StoredObject
	data class TooLarge(val size: Long) : StoredObject
}
