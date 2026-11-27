plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.compose)
}

// 어댑터 모듈(ADR-0015). Swift 브리지 프로토콜을 구현하고 값을 순수 뷰(`:feature:loggedout:ui`)에 넘긴다.
android {
    namespace = "com.unwrap.grep.feature.loggedout.adapter"
    compileSdk = 37
    defaultConfig { minSdk = 28 }
    buildFeatures { compose = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    api(project(":bridge"))
    api(project(":feature:loggedout:ui"))

    testImplementation(libs.junit)
}
