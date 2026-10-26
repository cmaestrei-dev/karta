import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// La llave con que se firma el APK del piloto (D7) va en android/key.properties, que no se sube al repositorio
// (ver docs/despliegue-aws.md). Sin ese archivo, el release se firma con la llave de depuración, como antes.
val llave = Properties().apply {
    val archivo = rootProject.file("key.properties")
    if (archivo.exists()) FileInputStream(archivo).use { load(it) }
}

android {
    namespace = "c.karta"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications usa APIs de java.time que en Android viejo llegan por desugaring.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "c.karta"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (!llave.isEmpty) {
            create("release") {
                keyAlias = llave.getProperty("keyAlias")
                keyPassword = llave.getProperty("keyPassword")
                storeFile = file(llave.getProperty("storeFile"))
                storePassword = llave.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (llave.isEmpty) "debug" else "release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
