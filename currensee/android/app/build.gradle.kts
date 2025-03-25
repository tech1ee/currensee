plugins { id("com.android.application"); id("kotlin-android"); id("dev.flutter.flutter-gradle-plugin") }

android { namespace = "com.currensee.currensee"; compileSdk = flutter.compileSdkVersion; ndkVersion = "27.0.12077973"; compileOptions { sourceCompatibility = JavaVersion.VERSION_1_8; targetCompatibility = JavaVersion.VERSION_1_8 }; kotlinOptions { jvmTarget = JavaVersion.VERSION_1_8.toString() }; sourceSets { getByName("main").java.srcDirs("src/main/kotlin") }; defaultConfig { applicationId = "com.currensee.currensee"; minSdk = 21; targetSdk = flutter.targetSdkVersion; versionCode = flutter.versionCode; versionName = flutter.versionName }; buildTypes { release { signingConfig = signingConfigs.getByName("debug"); isMinifyEnabled = true; isShrinkResources = true; proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro") } } }

flutter { source = "../.." }

dependencies { implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.9.22") }
