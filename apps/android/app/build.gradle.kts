plugins {
  alias(libs.plugins.android.application)
  alias(libs.plugins.compose.compiler)
  alias(libs.plugins.kotlin.serialization)
}

android {
    namespace = "com.example.creditcard"
    compileSdk = 36
    defaultConfig {
        applicationId = "com.applist.cardwallet"
        minSdk = 23
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    signingConfigs {
        create("release") {
            storeFile = file("release.jks")
            storePassword = "creditcard123"
            keyAlias = "releasekey"
            keyPassword = "creditcard123"
            isV1SigningEnabled = true
            isV2SigningEnabled = true
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.getByName("release")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildFeatures {
      compose = true
      aidl = false
      buildConfig = false
      shaders = false
    }

    androidResources {
      localeFilters += listOf("en", "zh")
    }

    packaging {
      resources {
        excludes += setOf(
          "/META-INF/{AL2.0,LGPL2.1}",
          "META-INF/LICENSE*",
          "META-INF/NOTICE*",
          "META-INF/*.kotlin_module"
        )
      }
    }

    dependenciesInfo {
      includeInApk = false
      includeInBundle = false
    }
}

kotlin {
    jvmToolchain(17)
}

dependencies {
  val composeBom = platform(libs.androidx.compose.bom)
  implementation(composeBom)
  androidTestImplementation(composeBom)

  // Core Android dependencies
  implementation(libs.androidx.core.ktx)
  implementation(libs.androidx.lifecycle.runtime.ktx)
  implementation(libs.androidx.activity.compose)

  // Arch Components
  implementation(libs.androidx.lifecycle.runtime.compose)
  implementation(libs.androidx.lifecycle.viewmodel.compose)
  implementation("androidx.fragment:fragment-ktx:1.8.5")
  implementation("androidx.biometric:biometric:1.1.0")

  // Compose
  implementation(libs.androidx.compose.ui)
  implementation(libs.androidx.compose.ui.tooling.preview)
  implementation(libs.androidx.compose.material3)
  // Tooling
  debugImplementation(libs.androidx.compose.ui.tooling)
  // Instrumented tests
  androidTestImplementation(libs.androidx.compose.ui.test.junit4)
  debugImplementation(libs.androidx.compose.ui.test.manifest)

  // Local tests: jUnit, coroutines, Android runner
  testImplementation(libs.junit)
  testImplementation(libs.kotlinx.coroutines.test)

  // Instrumented tests: jUnit rules and runners
  androidTestImplementation(libs.androidx.test.core)
  androidTestImplementation(libs.androidx.test.ext.junit)
  androidTestImplementation(libs.androidx.test.runner)
  androidTestImplementation(libs.androidx.test.espresso.core)

  // Navigation
  implementation(libs.androidx.navigation3.ui)
  implementation(libs.androidx.navigation3.runtime)
  implementation(libs.androidx.lifecycle.viewmodel.navigation3)

  // OkHttp 网络连接与 JSON 序列化支持
  implementation("com.squareup.okhttp3:okhttp:4.12.0")
  implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")
  
  // Compose 扩展矢量图标库
  implementation("androidx.compose.material:material-icons-extended")

  // CameraX 核心与 UI 视图组件支持
  val cameraxVersion = "1.3.1"
  implementation("androidx.camera:camera-core:$cameraxVersion")
  implementation("androidx.camera:camera-camera2:$cameraxVersion")
  implementation("androidx.camera:camera-lifecycle:$cameraxVersion")
  implementation("androidx.camera:camera-view:$cameraxVersion")

  // Google ML Kit Text Recognition 离线文本识别
  implementation("com.google.android.gms:play-services-mlkit-text-recognition:19.0.0")

  // ExifInterface 图片 Exif 物理方向识别
  implementation("androidx.exifinterface:exifinterface:1.3.7")
}
