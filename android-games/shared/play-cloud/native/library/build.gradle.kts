plugins { id("com.android.library"); kotlin("android") }
android {
    namespace = "com.dsschiff.games.cloud"
    compileSdk = 36
    defaultConfig { minSdk = 24 }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
}
dependencies {
    testImplementation("junit:junit:4.13.2")
    compileOnly("org.godotengine:godot:4.7.2.stable")
    implementation("com.google.android.gms:play-services-games-v2:22.1.0")
}
