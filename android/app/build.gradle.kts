import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val mobileEnvFile = rootProject.projectDir.parentFile.resolve(".env")
val mobileEnv = java.util.Properties().apply {
    if (mobileEnvFile.exists()) {
        mobileEnvFile.readLines().forEach { line ->
            val entry = line.trim()
            if (entry.isNotEmpty() && !entry.startsWith("#")) {
                val separator = entry.indexOf('=')
                if (separator > 0) {
                    setProperty(entry.substring(0, separator).trim(), entry.substring(separator + 1).trim().trim('"', '\''))
                }
            }
        }
    }
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "ru.prohelper.prohelpers_mobile"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "ru.prohelper.prohelpers_mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["rustoreProjectId"] = mobileEnv.getProperty("RUSTORE_PROJECT_ID", "")
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                null
            }
        }
    }
}

flutter {
    source = "../.."
}
