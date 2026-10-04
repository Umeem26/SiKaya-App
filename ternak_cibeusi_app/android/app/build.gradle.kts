import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Kunci rilis dibaca dari android/key.properties (tidak masuk git). Isi yang diharapkan:
// storeFile, storePassword, keyAlias, keyPassword. Path keystore relatif ke android/app.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}
val kunciWajib = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val kunciKurang = kunciWajib.filter { keystoreProperties.getProperty(it).isNullOrBlank() }
val kunciRilisLengkap = keystorePropertiesFile.exists() && kunciKurang.isEmpty()

android {
    namespace = "io.github.umeem26.sikaya"
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
        applicationId = "io.github.umeem26.sikaya"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (kunciRilisLengkap) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Tanpa key.properties, tugas cekKunciRilis di bawah menggagalkan build rilis.
            if (kunciRilisLengkap) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// Hanya dijalankan oleh build rilis (preReleaseBuild); build debug/profile tidak terpengaruh.
val cekKunciRilis = tasks.register("cekKunciRilis") {
    val adaFile = keystorePropertiesFile.exists()
    val kurang = kunciKurang.joinToString(", ")
    val lokasi = keystorePropertiesFile.path
    doLast {
        if (!adaFile) {
            throw GradleException(
                "Build rilis butuh kunci penandatanganan, tetapi $lokasi tidak ada.\n" +
                    "Buat file itu (jangan di-commit) berisi storeFile, storePassword, keyAlias, keyPassword.\n" +
                    "Build debug tidak memerlukannya: flutter build apk --debug",
            )
        }
        if (kurang.isNotEmpty()) {
            throw GradleException("$lokasi belum lengkap; isian kosong/tidak ada: $kurang")
        }
    }
}
tasks.matching { it.name == "preReleaseBuild" }.configureEach { dependsOn(cekKunciRilis) }

flutter {
    source = "../.."
}
