package com.unwrap.grep.features.archive.adapters.storage

import com.unwrap.grep.features.archive.domain.ObjectStorage
import com.unwrap.grep.features.archive.domain.StoredObject
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

	override fun put(objectPath: String, bytes: ByteArray) {
		client.putObject({ it.bucket(bucket).key(objectPath) }, RequestBody.fromBytes(bytes))
	}

	/** shortcut: 20MB까지 메모리로 읽는다. 상한을 크게 올리면 스트림으로 해시·판별하도록 바꾼다. */
	override fun read(objectPath: String, maxBytes: Long): StoredObject? {
		val size = try {
			client.headObject { it.bucket(bucket).key(objectPath) }.contentLength()
		} catch (e: S3Exception) {
			if (e is NoSuchKeyException || e.statusCode() == NOT_FOUND) return null
			throw e
		}
		if (size > maxBytes) return StoredObject.TooLarge(size)
		val bytes = client.getObjectAsBytes { it.bucket(bucket).key(objectPath) }.asByteArray()
		return StoredObject.Content(bytes)
	}

	override fun delete(objectPath: String) {
		client.deleteObject { it.bucket(bucket).key(objectPath) }
	}

	private companion object {
		const val DEFAULT_REGION = "us-east-1"
		const val NOT_FOUND = 404
	}
}
