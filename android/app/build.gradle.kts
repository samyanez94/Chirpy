import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.compose)
    alias(libs.plugins.serialization)
}

val chirpyProperties =
    Properties().apply {
        val file = rootProject.file("chirpy.properties")
        if (file.exists()) file.inputStream().use { load(it) }
    }

fun configValue(name: String, fallback: String = ""): String =
    providers.environmentVariable(name).orNull ?: chirpyProperties.getProperty(name, fallback)

fun quoted(value: String): String = "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""

android {
    namespace = "com.samuel.chirpy"
    compileSdk { version = release(37) { minorApiLevel = 0 } }
    defaultConfig {
        applicationId = "com.samuel.chirpy"
        minSdk = 26
        targetSdk = 37
        versionCode = 1
        versionName = "1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        buildConfigField(
            "String",
            "API_BASE_URL",
            quoted(configValue("CHIRPY_BASE_URL", "https://ncmomgqxdwrjwmoihayz.supabase.co/")),
        )
        buildConfigField("String", "API_KEY", quoted(configValue("CHIRPY_API_KEY")))
    }
    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
        }
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    lint { warningsAsErrors = true }
}

kotlin { compilerOptions { jvmTarget.set(JvmTarget.JVM_17) } }

dependencies {
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.material3)
    implementation(libs.compose.preview)
    implementation(libs.activity.compose)
    implementation(libs.lifecycle.compose)
    implementation(libs.lifecycle.viewmodel)
    implementation(libs.coroutines.android)
    implementation(libs.serialization)
    implementation(libs.retrofit)
    implementation(libs.retrofit.serialization)
    implementation(libs.okhttp)
    implementation(libs.coil.compose)
    implementation(libs.coil.network)
    debugImplementation(libs.compose.tooling)
    debugImplementation(libs.compose.test.manifest)
    testImplementation(libs.junit)
    testImplementation(libs.coroutines.test)
    testImplementation(libs.mockwebserver)
    androidTestImplementation(platform(libs.compose.bom))
    androidTestImplementation(libs.compose.test)
    androidTestImplementation(libs.android.test)
    androidTestImplementation(libs.android.runner)
}
