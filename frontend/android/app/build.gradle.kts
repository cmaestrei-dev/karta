import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// La llave con que se firma el APK del piloto (D7) va en android/key.properties, que no se sube al repositorio
// (ver docs/despliegue-aws.md). Sin ese archivo, un release falla: firmado con la llave de depuración no se podría
// instalar encima del APK del piloto. Para probar en local sin la llave: KARTA_FIRMA_DE_DEPURACION=1.
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
            // La comprobación va al armar el release, no al configurar: así flutter run (depuración) sigue igual.
        }
    }
}

flutter {
    source = "../.."
}

gradle.taskGraph.whenReady {
    val esRelease = allTasks.any { it.project == project && it.name.endsWith("Release") }
    if (esRelease && llave.isEmpty && System.getenv("KARTA_FIRMA_DE_DEPURACION") != "1") {
        throw GradleException(
            "Falta android/key.properties: el APK de release se firma con la llave de Karta " +
                "(deploy/android/crear_llave.sh). Para probar sin ella: KARTA_FIRMA_DE_DEPURACION=1."
        )
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
