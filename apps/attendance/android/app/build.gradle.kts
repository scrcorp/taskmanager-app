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
    //
    // worktree 격리: gradle property `-Pworktree=<브랜치>` 가 주어지면 dev flavor 에 한해
    // applicationId 와 라벨 suffix 를 추가해서 같은 에뮬레이터에 worktree 별로 독립 설치 가능.
    // 예: -Pworktree=feat/tips → com.tigersplus.taskmanager.attendance.dev.feattips,
    //                            라벨 "HTMA [DEV·feat-tips]"
    // staging/prod 빌드는 영향 받지 않음.
    val rawWorktree = (project.findProperty("worktree") as String?)?.trim()
    val wtId = rawWorktree
        ?.lowercase()
        ?.replace(Regex("[^a-z0-9]"), "")
        ?.takeIf { it.isNotBlank() }
    val wtLabel = rawWorktree
        ?.replace("/", "-")
        ?.takeIf { it.isNotBlank() }

    flavorDimensions += listOf("env")
    productFlavors {
        create("attendancedev") {
            dimension = "env"
            applicationId = "com.tigersplus.taskmanager.attendance.dev" +
                (wtId?.let { ".$it" } ?: "")
            manifestPlaceholders["envSuffix"] =
                " [DEV" + (wtLabel?.let { "·$it" } ?: "") + "]"
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
