rootProject.name = "grep-android"

// AGP·AndroidX는 Google 저장소에서만 찾는다(CI에서 AGP 플러그인을 못 찾는 일이 반복돼 순서를 앞으로 옮김).
pluginManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        gradlePluginPortal()
        mavenCentral()
    }
}

dependencyResolutionManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
    }
}

// µFeature 구조(ADR-0015). 공유 코어는 ../core, Android 화면 객체와 JNI는 swift/에 있다.
//   :bridge                Swift .so 빌드, swift-java 생성 Java 소스, 플랫폼 포트 구현, 공용 Compose 도우미
//   :feature:<f>:ui        순수 Compose 화면. :bridge에 의존하지 않는다
//   :feature:<f>:adapter   swift-java 브리지를 구현하고 값을 :ui에 넘기는 화면
//   :feature:<f>:demo      피처 하나만 띄우는 앱
//   :app                   모든 :adapter를 잇는 전체 앱
include(":bridge", ":app")
listOf("loggedout", "terminal", "loggedin").forEach { feature ->
    include(":feature:$feature:ui", ":feature:$feature:adapter", ":feature:$feature:demo")
}
