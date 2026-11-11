import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 正式签名配置（key.properties 不入库）
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}

android {
    namespace = "com.hermes.hermes_cards"
    compileSdk = flutter.compileSdkVersion
    // 本工程没有原生代码（插件全是 Java/Kotlin），不需要 NDK。
    // 保留 ndkVersion 会让 Gradle 下载 ~750MB 的 NDK，国内网络下常卡在解压阶段。

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.hermes.hermes_cards"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystoreProperties["storeFile"] != null) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                // 同时开 v1（JAR 签名）：部分国产 ROM / 应用市场只认 v1，不开会拒装
                enableV1Signing = true
                enableV2Signing = true
            }
        }
    }

    // 按 ABI 分包，避免一个包装进三种架构导致体积翻倍
    splits {
        abi {
            isEnable = true
            reset()
            include("arm64-v8a", "armeabi-v7a", "x86_64")
            isUniversalApk = true
        }
    }

    buildTypes {
        release {
            // 有正式签名就用正式签名，没有时退回调试签名，保证任何机器上都能出包
            signingConfig = if (keystoreProperties["storeFile"] != null)
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
    }
}

// 国内镜像优先，直连兜底
repositories {
    maven("https://maven.aliyun.com/repository/google")
    maven("https://maven.aliyun.com/repository/public")
    maven("https://mirrors.cloud.tencent.com/nexus/repository/maven-public/")
    google()
    mavenCentral()
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
