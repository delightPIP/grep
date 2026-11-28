package com.unwrap.grep.features.archive.item.adapters.storage

import com.unwrap.grep.features.archive.item.domain.ObjectStorage
import com.unwrap.grep.features.archive.item.domain.StoredObject
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider
import software.amazon.awssdk.core.sync.RequestBody
import software.amazon.awssdk.regions.Region
import software.amazon.awssdk.services.s3.S3Client
import software.amazon.awssdk.services.s3.S3Configuration
import software.amazon.awssdk.services.s3.model.NoSuchKeyException
import software.amazon.awssdk.services.s3.model.S3Exception
import software.amazon.awssdk.services.s3.presigner.S3Presigner
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest
import software.amazon.awssdk.services.s3.presigner.model.PutObjectPresignRequest
import java.net.URI
import java.time.Duration

/**
 * S3 호환 스토리지(Supabase Storage S3, ADR-BCK-002 결정 2). 버킷은 비공개다.
 * Supabase S3 엔드포인트는 경로 방식 주소(`<endpoint>/<bucket>/<key>`)로 부른다.
 * 클라이언트는 키가 없어도 서버가 뜨도록 처음 쓸 때 만든다.
 */
@Component
class S3ObjectStorage(
	@Value("\${grep.storage.s3.endpoint}") private val endpoint: String,
	@Value("\${grep.storage.s3.region}") private val region: String,
	@Value("\${grep.storage.s3.access-key-id}") private val accessKeyId: String,
	@Value("\${grep.storage.s3.secret-access-key}") private val secretAccessKey: String,
	@Value("\${grep.storage.bucket}") private val bucket: String,
) : ObjectStorage {

	private val credentials by lazy {
		StaticCredentialsProvider.create(AwsBasicCredentials.create(accessKeyId, secretAccessKey))
	}
	private val pathStyle = S3Configuration.builder().pathStyleAccessEnabled(true).build()
	private val awsRegion get() = Region.of(region.ifBlank { DEFAULT_REGION })

	private val client: S3Client by lazy {
		S3Client.builder()
			.endpointOverride(URI(endpoint))
			.region(awsRegion)
			.credentialsProvider(credentials)
			.serviceConfiguration(pathStyle)
			.build()
	}

	private val presigner: S3Presigner by lazy {
		S3Presigner.builder()
			.endpointOverride(URI(endpoint))
			.region(awsRegion)
			.credentialsProvider(credentials)
			.serviceConfiguration(pathStyle)
			.build()
	}

	override fun presignPut(objectPath: String, expiresIn: Duration): URI {
		val request = PutObjectPresignRequest.builder()
			.signatureDuration(expiresIn)
			.putObjectRequest { it.bucket(bucket).key(objectPath) }
			.build()
		return presigner.presignPutObject(request).url().toURI()
	}

	override fun presignGet(objectPath: String, expiresIn: Duration): URI {
		val request = GetObjectPresignRequest.builder()
			.signatureDuration(expiresIn)
			.getObjectRequest { it.bucket(bucket).key(objectPath) }
			.build()
		return presigner.presignGetObject(request).url().toURI()
	}

	override fun put(objectPath: String, bytes: ByteArray, contentType: String) {
		client.putObject({ it.bucket(bucket).key(objectPath).contentType(contentType) }, RequestBody.fromBytes(bytes))
	}

	/**
	 * 한 번의 GET으로 스트림을 열어 [maxBytes] + 1바이트까지만 읽는다(#117). 크기 확인과 읽기 사이에 객체가 바뀌어도 메모리는 상한을 넘지 않는다.
	 * 상한을 넘으면 남은 본문을 받지 않고 연결을 끊는다.
	 */
	override fun read(objectPath: String, maxBytes: Long): StoredObject? {
		val stream = try {
			client.getObject { it.bucket(bucket).key(objectPath) }
		} catch (e: S3Exception) {
			if (e is NoSuchKeyException || e.statusCode() == NOT_FOUND) return null
			throw e
		}
		stream.use {
			val declared = it.response().contentLength() ?: -1L
			if (declared > maxBytes) {
				it.abort()
				return StoredObject.TooLarge(declared)
			}
			val bytes = it.readNBytes(Math.toIntExact(maxBytes) + 1)
			if (bytes.size > maxBytes) {
				it.abort()
				return StoredObject.TooLarge(maxOf(declared, bytes.size.toLong()))
			}
			return StoredObject.Content(bytes)
		}
	}

	override fun delete(objectPath: String) {
		client.deleteObject { it.bucket(bucket).key(objectPath) }
	}

	private companion object {
		const val DEFAULT_REGION = "us-east-1"
		const val NOT_FOUND = 404
	}
}
