// Maven Central의 Google 미러를 먼저 본다. Render 빌드 서버는 repo.maven.apache.org에서 429(요청 제한)를 받는다(#176).
pluginManagement {
	repositories {
		maven("https://maven-central.storage-download.googleapis.com/maven2/")
		gradlePluginPortal()
	}
}

rootProject.name = "grep-server"
