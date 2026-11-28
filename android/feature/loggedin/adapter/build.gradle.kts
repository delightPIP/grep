plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.compose)
}

// 어댑터 모듈(ADR-0015). Swift 보관함 로더를 감싸고, 탭 상태를 순수 뷰(`:feature:loggedin:ui`)에 넘긴다.
android {
    namespace = "com.unwrap.grep.feature.loggedin.adapter"
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
    api(project(":feature:loggedin:ui"))

    testImplementation(libs.junit)
    testImplementation("org.json:json:20240303")
}
