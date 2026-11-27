plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

// 피처 하나만 띄우는 앱(ADR-0015). Swift 쪽은 FeatureDemoController가 맡는다.
android {
    namespace = "com.unwrap.grep.feature.loggedout.demo"
    compileSdk = 37
    defaultConfig {
        applicationId = "com.unwrap.grep.feature.loggedout.demo"
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
    implementation(project(":feature:loggedout:adapter"))
}
