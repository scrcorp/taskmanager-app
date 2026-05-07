import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

android {
    namespace = "com.tigersplus.attendance"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // 매장 태블릿 가로 강제
        manifestPlaceholders["screenOrientation"] = "sensorLandscape"
        manifestPlaceholders["appBaseName"] = "HTMA"
    }

    // env flavor 만 (mode 차원 없음 — attendance 전용 앱).
    // 같은 단말에 dev/staging/production .apk 동시 설치 가능 (applicationId 분리).
    // workflow release-attendance.yml 의 --flavor attendance{env} 와 일치하도록 합쳐진 이름 사용.
    flavorDimensions += listOf("env")
    productFlavors {
        create("attendancedev") {
            dimension = "env"
            applicationId = "com.tigersplus.taskmanager.attendance.dev"
            manifestPlaceholders["envSuffix"] = " [DEV]"
        }
        create("attendancestaging") {
            dimension = "env"
            applicationId = "com.tigersplus.taskmanager.attendance.staging"
            manifestPlaceholders["envSuffix"] = " [STG]"
        }
        create("attendanceproduction") {
            dimension = "env"
            applicationId = "com.tigersplus.taskmanager.attendance"
            manifestPlaceholders["envSuffix"] = ""
        }
    }

    buildTypes {
        release {
            // Sideload APK 배포 — debug signing 사용.
            // 정식 keystore 도입 시 signingConfigs 추가 후 여기서 참조.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
