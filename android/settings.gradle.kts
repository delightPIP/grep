rootProject.name = "grep-android"

pluginManagement {
    repositories {
        gradlePluginPortal()
        mavenCentral()
        google()
    }
}

dependencyResolutionManagement {
    repositories {
        mavenCentral()
        google()
    }
}

// µFeature 구조(ADR-0015). 공유 코어는 ../core, Android 화면 객체와 JNI는 swift/에 있다.
//   :bridge                Swift .so 빌드, swift-java 생성 Java 소스, 플랫폼 포트 구현, 공용 Compose 도우미
//   :feature:<f>:ui        순수 Compose 화면. :bridge에 의존하지 않는다
//   :feature:<f>:adapter   swift-java 브리지를 구현하고 값을 :ui에 넘기는 화면
//   :feature:<f>:demo      피처 하나만 띄우는 앱
//   :app                   모든 :adapter를 잇는 전체 앱
include(":bridge", ":app")
listOf("loggedout").forEach { feature ->
    include(":feature:$feature:ui", ":feature:$feature:adapter", ":feature:$feature:demo")
}
