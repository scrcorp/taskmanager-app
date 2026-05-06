plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.tigersplus.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 두 차원: mode (staff/attendance) × env (dev/staging/production).
    // 같은 단말에 mode×env 조합별 .apk 동시 설치 가능 (applicationId 분리).
    // 앱 이름은 manifestPlaceholders 의 appBaseName + envSuffix 로 동적 결합.
    flavorDimensions += listOf("mode", "env")
    productFlavors {
        create("staff") {
            dimension = "mode"
            applicationId = "com.tigersplus.taskmanager"
<<<<<<< HEAD
            manifestPlaceholders["appBaseName"] = "HTM"
=======
            manifestPlaceholders["appBaseName"] = "TaskManager"
            // staff 는 가로/세로 자유 (휴대폰에서 주로 세로)
            manifestPlaceholders["screenOrientation"] = "unspecified"
>>>>>>> feat/native-attendance-htma
        }
        create("attendance") {
            dimension = "mode"
            applicationId = "com.tigersplus.taskmanager.attendance"
            manifestPlaceholders["appBaseName"] = "HTMA"
            // 매장 태블릿 가로 강제 (Samsung 등 일부 기기는 sensorLandscape 무시 가능 —
            // MainActivity onCreate 에서 추가 강제)
            manifestPlaceholders["screenOrientation"] = "sensorLandscape"
        }
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            manifestPlaceholders["envSuffix"] = " [DEV]"
        }
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".staging"
            manifestPlaceholders["envSuffix"] = " [STG]"
        }
        create("production") {
            dimension = "env"
            // production = base 패키지, suffix 없음
            manifestPlaceholders["envSuffix"] = ""
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
