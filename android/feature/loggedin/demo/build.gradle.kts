plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

// 하단 탭(보관함·설정)만 띄우는 앱(ADR-0015). 보관함은 가짜 로더, 터미널 탭은 자리표시를 쓴다.
android {
    namespace = "com.unwrap.grep.feature.loggedin.demo"
    compileSdk = 37
    defaultConfig {
        applicationId = "com.unwrap.grep.feature.loggedin.demo"
        minSdk = 28
        targetSdk = 37
        versionCode = 1
        versionName = "0.1"
    }
    buildFeatures { compose = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    implementation(project(":feature:loggedin:adapter"))
    implementation(libs.androidx.activity.compose)
}
