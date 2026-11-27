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
}
