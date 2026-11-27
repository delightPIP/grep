plugins {
	kotlin("jvm") version "2.4.21"
	kotlin("plugin.spring") version "2.4.21"
	id("org.springframework.boot") version "4.2.0"
	id("io.spring.dependency-management") version "1.1.7"
}

group = "com.unwrap"
version = "0.0.1-SNAPSHOT"

java {
	toolchain {
		languageVersion = JavaLanguageVersion.of(21)
	}
}

repositories {
	mavenCentral()
}

dependencies {
	implementation("org.springframework.boot:spring-boot-starter-flyway")
	implementation("org.springframework.boot:spring-boot-starter-jdbc")
	implementation("org.springframework.boot:spring-boot-starter-security")
	implementation("org.springframework.boot:spring-boot-starter-security-oauth2-resource-server")
	implementation("org.springframework.boot:spring-boot-starter-validation")
	implementation("org.springframework.boot:spring-boot-starter-webmvc")
	implementation("org.flywaydb:flyway-database-postgresql")
	// 파일 원본은 S3 호환 스토리지(Supabase Storage S3, ADR-BCK-002 결정 2). 서명 URL과 객체 읽기·지우기에 쓴다.
	implementation(platform("software.amazon.awssdk:bom:2.59.5"))
	implementation("software.amazon.awssdk:s3")
	// PDF 글자 추출(COM-004 형식 표). docx는 표준 라이브러리로 읽는다.
	implementation("org.apache.pdfbox:pdfbox:3.0.8")
	// 링크 가져오기(ARC-006). 검사한 IP로만 연결하도록 이름 풀이를 바꿀 수 있는 클라이언트(#117 DNS 재바인딩). 버전은 Spring Boot가 관리한다.
	implementation("org.apache.httpcomponents.client5:httpclient5")
	// 가져온 HTML에서 본문 영역을 고른다(#117).
	implementation("org.jsoup:jsoup:1.24.1")
	implementation("org.jetbrains.kotlin:kotlin-reflect")
	implementation("tools.jackson.module:jackson-module-kotlin")
	runtimeOnly("org.postgresql:postgresql")
	testImplementation("org.springframework.boot:spring-boot-starter-flyway-test")
	testImplementation("org.springframework.boot:spring-boot-starter-jdbc-test")
	testImplementation("org.springframework.boot:spring-boot-starter-security-oauth2-resource-server-test")
	testImplementation("org.springframework.boot:spring-boot-starter-security-test")
	testImplementation("org.springframework.boot:spring-boot-starter-validation-test")
	testImplementation("org.springframework.boot:spring-boot-starter-webmvc-test")
	testImplementation("org.springframework.boot:spring-boot-testcontainers")
	testImplementation("org.jetbrains.kotlin:kotlin-test-junit5")
	testImplementation("org.testcontainers:testcontainers-junit-jupiter")
	testImplementation("org.testcontainers:testcontainers-postgresql")
	testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

kotlin {
	compilerOptions {
		freeCompilerArgs.addAll("-Xjsr305=strict", "-Xemit-jvm-type-annotations")
	}
}

tasks.withType<Test> {
	useJUnitPlatform()
}

// ADR-0010: 마이그레이션 원본은 루트 db/migrations 하나다. 서버 jar와 테스트에는 복사본을 넣는다.
tasks.processResources {
	from("../db/migrations") {
		into("db/migration")
	}
	// #102 샘플 8건(ARC-010). db/seed/samples/samples.json이 db/seed/demo의 자료를 가리키므로 둘 다 넣는다(835KB). POST /samples가 jar 안에서 읽는다.
	from("../db/seed") {
		include("samples/**", "demo/**")
		into("seed")
	}
}

// #69 데모 시드: ./gradlew seedDemo -Pemail=<계정 이메일> [-Pprovider=google]. 서버와 같은 DB·스토리지 환경변수를 쓴다.
// 시드 도구(DemoSeedMain)도 main이 있어 bootRun·bootJar가 실행 클래스를 고르지 못한다. 서버 진입점을 못 박는다
springBoot {
	mainClass = "com.unwrap.grep.GrepServerApplicationKt"
}

tasks.register<JavaExec>("seedDemo") {
	group = "application"
	description = "db/seed/demo/seed.json 34건을 지정한 계정에 넣는다(demo-seed 2절)."
	classpath = sourceSets["main"].runtimeClasspath
	mainClass = "com.unwrap.grep.features.demoseed.DemoSeedMainKt"
	// Windows 콘솔에서도 한글 결과가 깨지지 않게
	jvmArgs("-Dstdout.encoding=UTF-8", "-Dstderr.encoding=UTF-8")
	val email = providers.gradleProperty("email")
	val provider = providers.gradleProperty("provider").orElse("google")
	val seedDir = layout.projectDirectory.dir("../db/seed/demo").asFile.absolutePath
	argumentProviders.add(CommandLineArgumentProvider {
		listOf("--email=${email.getOrElse("")}", "--provider=${provider.get()}", "--seed-dir=$seedDir")
	})
}
