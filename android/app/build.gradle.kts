import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release imzalama sırları ASLA repoda tutulmaz. İki kaynak desteklenir:
// 1) Ortam değişkenleri (CI için) — öncelikli
// 2) android/key.properties (yerel geliştirici makinesi) — gitignore'da
// Bkz. android/key.properties.example
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}

fun signingSecret(envName: String, propertyName: String): String? =
    System.getenv(envName) ?: keystoreProperties.getProperty(propertyName)

val releaseStoreFile = signingSecret("ANDROID_KEYSTORE_PATH", "storeFile")
val releaseStorePassword = signingSecret("ANDROID_KEYSTORE_PASSWORD", "storePassword")
val releaseKeyAlias = signingSecret("ANDROID_KEY_ALIAS", "keyAlias")
val releaseKeyPassword = signingSecret("ANDROID_KEY_PASSWORD", "keyPassword")

val hasReleaseSigning = listOf(
    releaseStoreFile,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).none { it.isNullOrBlank() }

if (!hasReleaseSigning) {
    // println kullanılıyor: logger.warn Flutter'ın varsayılan Gradle log
    // seviyesinde YUTULUYOR (ölçüldü — çıktıda hiç görünmedi). İmzasız APK
    // sessizce üretilmemeli; geliştirici nedenini görmeli.
    println(
        """
        ============================================================
        UYARI: Release imzalama yapılandırması bulunamadı.
        Release çıktısı İMZASIZ üretilecek ve mağazaya yüklenemez.

        Çözüm — ortam değişkenleri (CI) ya da android/key.properties:
          ANDROID_KEYSTORE_PATH, ANDROID_KEYSTORE_PASSWORD,
          ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD
        Biçim için: android/key.properties.example
        ============================================================
        """.trimIndent()
    )
}

android {
    namespace = "com.suretakip.app"
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
        applicationId = "com.suretakip.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // Debug anahtarına ASLA geri düşülmez: imzasız çıktı fark edilir,
            // debug anahtarıyla imzalanmış çıktı sessizce mağazaya gider.
            signingConfig = if (hasReleaseSigning) {
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
