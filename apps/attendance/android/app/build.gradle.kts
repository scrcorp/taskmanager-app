import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Release 서명 키 ────────────────────────────────────────────────────────
// android/key.properties (gitignore 대상) 가 있으면 정식 keystore 로 서명한다.
//
// **왜 이게 중요한가**: 예전엔 release 도 debug 서명을 썼는데, debug.keystore 는
// 머신마다 자동 생성되는 파일이라 빌드하는 맥북이 바뀌면 서명이 달라진다.
// 그러면 매장 태블릿에서 "App not installed as package conflicts with an existing
// package" 로 업데이트가 거부된다 (2026-08-08 v1.0.12+33 실제 사고).
// 누가 어디서 빌드하든 같은 키로 서명되어야 업데이트가 이어진다.
//
// key.properties 가 없으면 debug 서명으로 폴백한다 — 키 없는 개발자도 로컬
// 빌드/실행은 되게 하기 위함. 단 그렇게 만든 APK 는 **배포 불가**이므로,
// 릴리스는 반드시 scripts/release-attendance.sh 를 통해서만 한다
// (그 스크립트가 빌드 후 서명 지문을 검증한다).
val keystorePropsFile = rootProject.file("key.properties")
val keystoreProps = Properties().apply {
    if (keystorePropsFile.exists()) {
        keystorePropsFile.inputStream().use { load(it) }
    }
}
val hasReleaseKeystore = keystoreProps.getProperty("storeFile")?.isNotBlank() == true

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

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                // storeFile 은 ~ 확장이 안 되므로 key.properties 에 절대경로를 쓴다.
                storeFile = file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // key.properties 가 있으면 정식 키, 없으면 debug 폴백(배포 불가 빌드).
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
