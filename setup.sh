#!/usr/bin/env bash
set -euo pipefail

echo "=== Sync app — bootstrap ==="
mkdir -p .github/workflows
mkdir -p scripts
mkdir -p docs
mkdir -p app/src/main/cpp
mkdir -p app/src/main/java/com/nova/sync/data
mkdir -p app/src/main/java/com/nova/sync/player
mkdir -p app/src/main/java/com/nova/sync/ui/components
mkdir -p app/src/main/java/com/nova/sync/ui/theme
mkdir -p app/src/main/res/values
mkdir -p app/src/main/res/xml
mkdir -p app/src/main/res/drawable
mkdir -p app/src/main/res/mipmap-anydpi-v26
mkdir -p app/src/main/res/mipmap-anydpi

# ============ Gradle ============
cat > settings.gradle.kts << 'EOF'
pluginManagement {
    repositories { google(); mavenCentral(); gradlePluginPortal() }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { google(); mavenCentral() }
}
rootProject.name = "Sync"
include(":app")
EOF

cat > build.gradle.kts << 'EOF'
plugins {
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.21" apply false
    id("org.jetbrains.kotlin.plugin.serialization") version "2.0.21" apply false
}
EOF

cat > gradle.properties << 'EOF'
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
kotlin.code.style=official
android.nonTransitiveRClass=true
android.defaults.buildfeatures.buildconfig=true
EOF

cat > app/build.gradle.kts << 'EOF'
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

android {
    namespace = "com.nova.sync"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.nova.sync"
        minSdk = 23
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
        ndk { abiFilters += listOf("arm64-v8a", "armeabi-v7a") }
    }

    signingConfigs {
        create("release") {
            val b64 = System.getenv("SGN_B64")
            if (!b64.isNullOrBlank()) {
                val f = File(rootDir, "keystore.jks")
                f.writeBytes(android.util.Base64.decode(b64, android.util.Base64.DEFAULT))
                storeFile = f
                storePassword = System.getenv("SGN_P1")
                keyAlias = System.getenv("SGN_K")
                keyPassword = System.getenv("SGN_P1")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            if (!System.getenv("SGN_B64").isNullOrBlank()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    externalNativeBuild {
        cmake { path = file("src/main/cpp/CMakeLists.txt") }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { compose = true }
    packaging { resources.excludes += "/META-INF/{AL2.0,LGPL2.1}" }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")

    implementation(platform("androidx.compose:compose-bom:2024.11.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.navigation:navigation-compose:2.8.4")

    implementation("androidx.tv:tv-material:1.0.0")

    implementation("androidx.media3:media3-exoplayer:1.4.1")
    implementation("androidx.media3:media3-exoplayer-hls:1.4.1")
    implementation("androidx.media3:media3-ui:1.4.1")
    implementation("androidx.media3:media3-datasource-okhttp:1.4.1")

    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    implementation("io.coil-kt:coil-compose:2.7.0")
}
EOF

cat > app/proguard-rules.pro << 'EOF'
-keep class com.nova.sync.data.** { *; }
-keepclasseswithmembernames class * { native <methods>; }
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.**
-keepclassmembers class kotlinx.serialization.json.** { *** Companion; }
-keepclasseswithmembers class kotlinx.serialization.json.** { kotlinx.serialization.KSerializer serializer(...); }
-keep,includedescriptorclasses class com.nova.sync.**$$serializer { *; }
-keepclassmembers class com.nova.sync.** { *** Companion; }
EOF

# ============ Manifest ============
cat > app/src/main/AndroidManifest.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>

    <uses-feature android:name="android.software.leanback" android:required="false"/>
    <uses-feature android:name="android.hardware.touchscreen" android:required="false"/>

    <application
        android:name=".App"
        android:allowBackup="false"
        android:banner="@drawable/banner"
        android:icon="@mipmap/ic_launcher"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:label="@string/app_name"
        android:theme="@style/Theme.Sync"
        android:usesCleartextTraffic="false"
        android:networkSecurityConfig="@xml/network_security_config">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:configChanges="keyboard|keyboardHidden|navigation|orientation|screenLayout|screenSize|smallestScreenSize|uiMode"
            android:launchMode="singleTask"
            android:screenOrientation="landscape">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LEANBACK_LAUNCHER"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

# ============ Resources ============
cat > app/src/main/res/values/strings.xml << 'EOF'
<resources>
    <string name="app_name">Sync</string>
</resources>
EOF

cat > app/src/main/res/values/colors.xml << 'EOF'
<resources>
    <color name="ic_launcher_background">#4F46E5</color>
</resources>
EOF

cat > app/src/main/res/values/themes.xml << 'EOF'
<resources>
    <style name="Theme.Sync" parent="android:Theme.Material.NoActionBar">
        <item name="android:windowBackground">@android:color/black</item>
        <item name="android:statusBarColor">@android:color/black</item>
        <item name="android:navigationBarColor">@android:color/black</item>
    </style>
</resources>
EOF

cat > app/src/main/res/xml/network_security_config.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="false"/>
</network-security-config>
EOF

cat > app/src/main/res/drawable/ic_launcher_background.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:aapt="http://schemas.android.com/aapt"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path android:pathData="M0,0h108v108h-108z">
        <aapt:attr name="android:fillColor">
            <gradient
                android:type="linear"
                android:startX="0" android:startY="0"
                android:endX="108" android:endY="108">
                <item android:offset="0" android:color="#FF4F46E5"/>
                <item android:offset="1" android:color="#FF7C3AED"/>
            </gradient>
        </aapt:attr>
    </path>
</vector>
EOF

cat > app/src/main/res/drawable/ic_launcher_foreground.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <group android:scaleX="2.4" android:scaleY="2.4"
           android:translateX="25.2" android:translateY="25.2">
        <path
            android:fillColor="#FFFFFF"
            android:pathData="M12,4V1L8,5l4,4V6c3.31,0 6,2.69 6,6 0,1.01 -0.25,1.97 -0.7,2.8l1.46,1.46C19.54,15.03 20,13.57 20,12c0,-4.42 -3.58,-8 -8,-8zM12,18c-3.31,0 -6,-2.69 -6,-6 0,-1.01 0.25,-1.97 0.7,-2.8L5.24,7.74C4.46,8.97 4,10.43 4,12c0,4.42 3.58,8 8,8v3l4,-4 -4,-4v3z"/>
    </group>
</vector>
EOF

cat > app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
EOF

cat > app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
EOF

cat > app/src/main/res/mipmap-anydpi/ic_launcher.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:aapt="http://schemas.android.com/aapt"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path android:pathData="M0,0h108v108h-108z">
        <aapt:attr name="android:fillColor">
            <gradient
                android:type="linear"
                android:startX="0" android:startY="0"
                android:endX="108" android:endY="108">
                <item android:offset="0" android:color="#FF4F46E5"/>
                <item android:offset="1" android:color="#FF7C3AED"/>
            </gradient>
        </aapt:attr>
    </path>
    <group android:scaleX="2.4" android:scaleY="2.4"
           android:translateX="25.2" android:translateY="25.2">
        <path
            android:fillColor="#FFFFFF"
            android:pathData="M12,4V1L8,5l4,4V6c3.31,0 6,2.69 6,6 0,1.01 -0.25,1.97 -0.7,2.8l1.46,1.46C19.54,15.03 20,13.57 20,12c0,-4.42 -3.58,-8 -8,-8zM12,18c-3.31,0 -6,-2.69 -6,-6 0,-1.01 0.25,-1.97 0.7,-2.8L5.24,7.74C4.46,8.97 4,10.43 4,12c0,4.42 3.58,8 8,8v3l4,-4 -4,-4v3z"/>
    </group>
</vector>
EOF

cat > app/src/main/res/mipmap-anydpi/ic_launcher_round.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:aapt="http://schemas.android.com/aapt"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path android:pathData="M0,0h108v108h-108z">
        <aapt:attr name="android:fillColor">
            <gradient
                android:type="linear"
                android:startX="0" android:startY="0"
                android:endX="108" android:endY="108">
                <item android:offset="0" android:color="#FF4F46E5"/>
                <item android:offset="1" android:color="#FF7C3AED"/>
            </gradient>
        </aapt:attr>
    </path>
    <group android:scaleX="2.4" android:scaleY="2.4"
           android:translateX="25.2" android:translateY="25.2">
        <path
            android:fillColor="#FFFFFF"
            android:pathData="M12,4V1L8,5l4,4V6c3.31,0 6,2.69 6,6 0,1.01 -0.25,1.97 -0.7,2.8l1.46,1.46C19.54,15.03 20,13.57 20,12c0,-4.42 -3.58,-8 -8,-8zM12,18c-3.31,0 -6,-2.69 -6,-6 0,-1.01 0.25,-1.97 0.7,-2.8L5.24,7.74C4.46,8.97 4,10.43 4,12c0,4.42 3.58,8 8,8v3l4,-4 -4,-4v3z"/>
    </group>
</vector>
EOF

cat > app/src/main/res/drawable/banner.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:aapt="http://schemas.android.com/aapt"
    android:width="320dp"
    android:height="180dp"
    android:viewportWidth="320"
    android:viewportHeight="180">
    <path android:pathData="M0,0h320v180h-320z">
        <aapt:attr name="android:fillColor">
            <gradient
                android:type="linear"
                android:startX="0" android:startY="0"
                android:endX="320" android:endY="180">
                <item android:offset="0" android:color="#FF4F46E5"/>
                <item android:offset="1" android:color="#FF7C3AED"/>
            </gradient>
        </aapt:attr>
    </path>
    <group android:translateX="122" android:translateY="52">
        <group android:scaleX="3" android:scaleY="3">
            <path
                android:fillColor="#FFFFFF"
                android:pathData="M12,4V1L8,5l4,4V6c3.31,0 6,2.69 6,6 0,1.01 -0.25,1.97 -0.7,2.8l1.46,1.46C19.54,15.03 20,13.57 20,12c0,-4.42 -3.58,-8 -8,-8zM12,18c-3.31,0 -6,-2.69 -6,-6 0,-1.01 0.25,-1.97 0.7,-2.8L5.24,7.74C4.46,8.97 4,10.43 4,12c0,4.42 3.58,8 8,8v3l4,-4 -4,-4v3z"/>
        </group>
    </group>
</vector>
EOF

# ============ NDK ============
cat > app/src/main/cpp/CMakeLists.txt << 'EOF'
cmake_minimum_required(VERSION 3.22.1)
project("sigcheck")
add_library(sigcheck SHARED sigcheck.cpp)
find_library(log-lib log)
target_link_libraries(sigcheck ${log-lib})
EOF

cat > app/src/main/cpp/sigcheck.cpp << 'EOF'
#include <jni.h>
#include <string>
#include <cstdint>
#include <unistd.h>
#include <sys/ptrace.h>
#include <cstdio>

static const unsigned char kKey = 0x5B;

// XOR-encoded "https://gvineon550-coder.github.io/cfg-sync/"
static const unsigned char kPagesBase[] = {
    0x33,0x2F,0x2F,0x2B,0x28,0x61,0x74,0x74,0x3C,0x2D,0x32,0x35,0x3E,0x34,0x35,
    0x6E,0x6E,0x6B,0x76,0x38,0x34,0x3F,0x3E,0x29,0x75,0x3C,0x32,0x2F,0x33,0x2E,
    0x39,0x75,0x32,0x34,0x74,0x38,0x3D,0x3C,0x76,0x28,0x22,0x35,0x38,0x74
};

// XOR-encoded "https://rutube.ru/api/play/options/%s/"
static const unsigned char kPlayTpl[] = {
    0x33,0x2F,0x2F,0x2B,0x28,0x61,0x74,0x74,0x29,0x2E,0x2F,0x2E,0x39,0x3E,0x75,
    0x29,0x2E,0x74,0x3A,0x2B,0x32,0x74,0x2B,0x37,0x3A,0x22,0x74,0x34,0x2B,0x2F,
    0x32,0x34,0x35,0x28,0x74,0x7E,0x28,0x74
};

static std::string decode(const unsigned char* data, size_t len) {
    std::string out; out.reserve(len);
    for (size_t i = 0; i < len; ++i)
        out.push_back(static_cast<char>(data[i] ^ kKey));
    return out;
}

static bool isTampered() {
    // ptrace-based anti-debug (only works if not already traced; safe in prod)
    if (ptrace(PTRACE_TRACEME, 0, nullptr, nullptr) == -1) return true;

    // look for Frida / Magisk in maps
    FILE* f = fopen("/proc/self/maps", "r");
    if (!f) return false;
    char line[512];
    bool bad = false;
    while (fgets(line, sizeof(line), f)) {
        if (strstr(line, "frida") || strstr(line, "magisk") ||
            strstr(line, "xposed") || strstr(line, "substrate")) {
            bad = true; break;
        }
    }
    fclose(f);
    return bad;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_nova_sync_NativeStrings_nativeUrl(JNIEnv* env, jobject, jint idx) {
    if (idx == 0) {
        std::string s = decode(kPagesBase, sizeof(kPagesBase));
        return env->NewStringUTF(s.c_str());
    }
    if (idx == 1) {
        std::string s = decode(kPlayTpl, sizeof(kPlayTpl));
        return env->NewStringUTF(s.c_str());
    }
    return nullptr;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_nova_sync_SignatureGuard_nativeIsTampered(JNIEnv*, jobject) {
    return isTampered() ? JNI_TRUE : JNI_FALSE;
}
EOF

# ============ Kotlin: App ============
cat > app/src/main/java/com/nova/sync/App.kt << 'EOF'
package com.nova.sync

import android.app.Application
import com.nova.sync.data.FavoritesStore
import com.nova.sync.data.HistoryStore

class App : Application() {
    override fun onCreate() {
        super.onCreate()
        FavoritesStore.init(this)
        HistoryStore.init(this)
        SignatureGuard.init(this)
    }
}
EOF

cat > app/src/main/java/com/nova/sync/NativeStrings.kt << 'EOF'
package com.nova.sync

object NativeStrings {
    private val loaded: Boolean = try {
        System.loadLibrary("sigcheck"); true
    } catch (_: Throwable) { false }

    private external fun nativeUrl(idx: Int): String?

    val pagesBase: String
        get() = if (loaded) (nativeUrl(0) ?: "") else ""
    val playOptionsTemplate: String
        get() = if (loaded) (nativeUrl(1) ?: "") else ""
}
EOF

cat > app/src/main/java/com/nova/sync/SignatureGuard.kt << 'EOF'
package com.nova.sync

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import com.nova.sync.data.TrustedDeviceStore
import java.security.MessageDigest

sealed class TrustState {
    object Trusted : TrustState()
    data class Untrusted(val androidId: String) : TrustState()
    data class Unreliable(val reason: String) : TrustState()
}

object SignatureGuard {
    private const val EXPECTED_SHA256 =
        "0f407f281165dd946ccf13aed1b171e02fdadd538894af7ce12826e7bf300b5a"

    private var appCtx: Context? = null
    private val loaded: Boolean = try {
        System.loadLibrary("sigcheck"); true
    } catch (_: Throwable) { false }

    fun init(ctx: Context) { appCtx = ctx.applicationContext }

    suspend fun resolve(): TrustState {
        val ctx = appCtx ?: return TrustState.Unreliable("no_context")

        val actual = signatureSha256(ctx) ?: return TrustState.Unreliable("no_signature")
        if (!actual.equals(EXPECTED_SHA256, ignoreCase = true)) {
            return TrustState.Unreliable("bad_signature")
        }

        if (loaded && nativeIsTampered()) {
            return TrustState.Unreliable("tampered")
        }

        val androidId = Settings.Secure.getString(
            ctx.contentResolver, Settings.Secure.ANDROID_ID
        ) ?: return TrustState.Unreliable("no_android_id")

        TrustedDeviceStore.refresh()
        return if (TrustedDeviceStore.isTrusted(androidId))
            TrustState.Trusted
        else
            TrustState.Untrusted(androidId)
    }

    private fun signatureSha256(ctx: Context): String? = try {
        val pm = ctx.packageManager
        val pkg = if (Build.VERSION.SDK_INT >= 33)
            pm.getPackageInfo(
                ctx.packageName,
                PackageManager.PackageInfoFlags.of(
                    PackageManager.GET_SIGNING_CERTIFICATES.toLong()
                )
            )
        else
            @Suppress("DEPRECATION")
            pm.getPackageInfo(ctx.packageName, PackageManager.GET_SIGNING_CERTIFICATES)

        val signatures = if (Build.VERSION.SDK_INT >= 28)
            pkg.signingInfo?.apkContentsSigners
        else
            @Suppress("DEPRECATION") pkg.signatures

        val sig = signatures?.firstOrNull() ?: return null
        MessageDigest.getInstance("SHA-256")
            .digest(sig.toByteArray())
            .joinToString("") { "%02x".format(it) }
    } catch (_: Throwable) { null }

    private external fun nativeIsTampered(): Boolean
}
EOF

# ============ Kotlin: data ============
cat > app/src/main/java/com/nova/sync/data/Models.kt << 'EOF'
package com.nova.sync.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class Channel(
    val id: String,
    val title: String = "",
    val description: String = "",
    val category: String? = null,
    val avatar: String = "",
    @SerialName("stream_url") val streamUrl: String? = null,
    val blocked: Boolean = false,
    @SerialName("blocked_reason") val blockedReason: String = "",
    val unavailable: Boolean = false,
)

@Serializable
data class Catalog(
    val updated: String = "",
    val total: Int = 0,
    @SerialName("with_url") val withUrl: Int = 0,
    @SerialName("no_url") val noUrl: Int = 0,
    val channels: List<Channel> = emptyList(),
)

@Serializable
data class TrustedDevices(
    val devices: List<String> = emptyList(),
)
EOF

cat > app/src/main/java/com/nova/sync/data/FavoritesStore.kt << 'EOF'
package com.nova.sync.data

import android.content.Context
import android.content.SharedPreferences

object FavoritesStore {
    private lateinit var prefs: SharedPreferences
    fun init(ctx: Context) {
        prefs = ctx.getSharedPreferences("f", Context.MODE_PRIVATE)
    }
    fun all(): Set<String> = prefs.getStringSet("f", emptySet()) ?: emptySet()
    fun toggle(id: String): Set<String> {
        val s = all().toMutableSet()
        if (!s.add(id)) s.remove(id)
        prefs.edit().putStringSet("f", s).apply()
        return s
    }
}
EOF

cat > app/src/main/java/com/nova/sync/data/HistoryStore.kt << 'EOF'
package com.nova.sync.data

import android.content.Context
import android.content.SharedPreferences

object HistoryStore {
    private lateinit var prefs: SharedPreferences
    fun init(ctx: Context) {
        prefs = ctx.getSharedPreferences("h", Context.MODE_PRIVATE)
    }
    fun all(): List<String> =
        prefs.getString("h", "").orEmpty().split(",").filter { it.isNotBlank() }
    fun push(id: String) {
        val l = all().toMutableList()
        l.remove(id); l.add(0, id)
        prefs.edit().putString("h", l.take(50).joinToString(",")).apply()
    }
}
EOF

cat > app/src/main/java/com/nova/sync/data/Repository.kt << 'EOF'
package com.nova.sync.data

import com.nova.sync.NativeStrings
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

object Repository {
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(20, TimeUnit.SECONDS)
        .build()

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    suspend fun loadCatalog(): Result<Catalog> = withContext(Dispatchers.IO) {
        runCatching {
            val url = NativeStrings.pagesBase + "c.json"
            val req = Request.Builder().url(url).build()
            client.newCall(req).execute().use { resp ->
                require(resp.isSuccessful) { "HTTP ${resp.code}" }
                val body = resp.body?.string().orEmpty()
                json.decodeFromString<Catalog>(body)
            }
        }
    }
}
EOF

cat > app/src/main/java/com/nova/sync/data/TrustedDeviceStore.kt << 'EOF'
package com.nova.sync.data

import com.nova.sync.NativeStrings
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

object TrustedDeviceStore {
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(20, TimeUnit.SECONDS)
        .build()
    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    @Volatile private var cache: Set<String>? = null

    suspend fun refresh() = withContext(Dispatchers.IO) {
        runCatching {
            val url = NativeStrings.pagesBase + "trusted_devices.json"
            val req = Request.Builder().url(url).build()
            client.newCall(req).execute().use { resp ->
                require(resp.isSuccessful) { "HTTP ${resp.code}" }
                val body = resp.body?.string().orEmpty()
                val td = json.decodeFromString<TrustedDevices>(body)
                cache = td.devices.toSet()
            }
        }
    }

    fun isTrusted(id: String): Boolean = cache?.contains(id) == true
    fun cached(): Set<String> = cache ?: emptySet()
}
EOF

cat > app/src/main/java/com/nova/sync/data/Resolver.kt << 'EOF'
package com.nova.sync.data

import com.nova.sync.NativeStrings
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

object Resolver {
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(20, TimeUnit.SECONDS)
        .build()
    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    suspend fun resolveStream(channelId: String): String? = withContext(Dispatchers.IO) {
        runCatching {
            val tpl = NativeStrings.playOptionsTemplate
            if (tpl.isEmpty()) return@runCatching null
            val url = tpl.replace("%s", channelId)
            val req = Request.Builder()
                .url(url)
                .header(
                    "User-Agent",
                    "Mozilla/5.0 (Linux; Android TV) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
                )
                .header("Referer", "https://rutube.ru/")
                .build()
            client.newCall(req).execute().use { resp ->
                require(resp.isSuccessful) { "HTTP ${resp.code}" }
                val body = resp.body?.string().orEmpty()
                val obj = json.parseToJsonElement(body).jsonObject
                val live = obj["live_streams"]?.jsonObject ?: return@runCatching null
                val hls = live["hls"]?.jsonArray ?: return@runCatching null
                val first = hls.firstOrNull()?.jsonObject ?: return@runCatching null
                first["url"]?.jsonPrimitive?.content
            }
        }.getOrNull()
    }
}
EOF

# ============ Kotlin: player ============
cat > app/src/main/java/com/nova/sync/player/PlayerHolder.kt << 'EOF'
package com.nova.sync.player

import com.nova.sync.data.Channel

object PlayerHolder {
    var current: Channel? = null
}
EOF

cat > app/src/main/java/com/nova/sync/player/ChannelsViewModel.kt << 'EOF'
package com.nova.sync.player

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.nova.sync.data.Channel
import com.nova.sync.data.FavoritesStore
import com.nova.sync.data.Repository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class ChannelsUiState(
    val loading: Boolean = true,
    val error: String? = null,
    val channels: List<Channel> = emptyList(),
    val favorites: Set<String> = emptySet(),
)

class ChannelsViewModel : ViewModel() {
    private val _state = MutableStateFlow(ChannelsUiState())
    val state: StateFlow<ChannelsUiState> = _state.asStateFlow()

    init { load() }

    fun load() {
        _state.value = _state.value.copy(loading = true, error = null)
        viewModelScope.launch {
            Repository.loadCatalog()
                .onSuccess { cat ->
                    _state.value = ChannelsUiState(
                        loading = false,
                        channels = cat.channels,
                        favorites = FavoritesStore.all(),
                    )
                }
                .onFailure { e ->
                    _state.value = _state.value.copy(
                        loading = false,
                        error = e.message ?: "error",
                    )
                }
        }
    }

    fun toggleFavorite(id: String) {
        val favs = FavoritesStore.toggle(id)
        _state.value = _state.value.copy(favorites = favs)
    }
}
EOF

# ============ Kotlin: ui ============
cat > app/src/main/java/com/nova/sync/ui/theme/Theme.kt << 'EOF'
package com.nova.sync.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val Colors = darkColorScheme(
    primary = Color(0xFF7C3AED),
    onPrimary = Color.White,
    background = Color(0xFF000000),
    onBackground = Color.White,
    surface = Color(0xFF141414),
    onSurface = Color.White,
)

@Composable
fun AppTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = Colors, content = content)
}
EOF

cat > app/src/main/java/com/nova/sync/ui/components/TvButton.kt << 'EOF'
package com.nova.sync.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.tv.material3.Card
import androidx.tv.material3.ExperimentalTvMaterial3Api

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
fun TvButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Card(onClick = onClick, modifier = modifier) {
        Box(
            modifier = Modifier
                .background(Color(0xFF1F1F1F))
                .padding(horizontal = 22.dp, vertical = 12.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(text, color = Color.White, fontWeight = FontWeight.Medium, style = MaterialTheme.typography.titleMedium)
        }
    }
}
EOF

cat > app/src/main/java/com/nova/sync/ui/components/ChannelCard.kt << 'EOF'
package com.nova.sync.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.tv.material3.Card
import androidx.tv.material3.ExperimentalTvMaterial3Api
import coil.compose.AsyncImage
import com.nova.sync.data.Channel

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
fun ChannelCard(channel: Channel, onClick: () -> Unit) {
    Card(onClick = onClick, modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(Color(0xFF141414))
                .padding(18.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (channel.avatar.isNotBlank()) {
                AsyncImage(
                    model = channel.avatar,
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .size(112.dp, 63.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(Color.Black),
                )
            } else {
                Box(
                    modifier = Modifier
                        .size(112.dp, 63.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(Color(0xFF2A2A2A))
                )
            }
            Spacer(Modifier.width(18.dp))
            Column(Modifier.weight(1f)) {
                Text(
                    channel.title.ifBlank { channel.id },
                    color = Color.White,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.SemiBold,
                )
                if (!channel.category.isNullOrBlank()) {
                    Spacer(Modifier.height(4.dp))
                    Text(channel.category, color = Color(0xFF9AA0A6))
                }
            }
        }
    }
}
EOF

cat > app/src/main/java/com/nova/sync/ui/RootScreen.kt << 'EOF'
package com.nova.sync.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import com.nova.sync.SignatureGuard
import com.nova.sync.TrustState

@Composable
fun RootScreen() {
    var recheck by remember { mutableIntStateOf(0) }
    var state by remember { mutableStateOf<TrustState?>(null) }
    LaunchedEffect(recheck) { state = SignatureGuard.resolve() }
    Box(Modifier.fillMaxSize().background(Color.Black)) {
        when (val s = state) {
            null -> {}
            is TrustState.Trusted -> AppNav()
            is TrustState.Untrusted -> UntrustedScreen(
                androidId = s.androidId,
                onRecheck = { recheck++ },
            )
            is TrustState.Unreliable -> UntrustedScreen(
                androidId = "",
                onRecheck = { recheck++ },
                reason = s.reason,
            )
        }
    }
}
EOF

cat > app/src/main/java/com/nova/sync/ui/AppNav.kt << 'EOF'
package com.nova.sync.ui

import androidx.compose.runtime.Composable
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.nova.sync.player.PlayerHolder

@Composable
fun AppNav() {
    val nav = rememberNavController()
    NavHost(nav, startDestination = "channels") {
        composable("channels") {
            ChannelsScreen(
                onChannelClick = { ch -> PlayerHolder.current = ch; nav.navigate("player") },
                onFavorites = { nav.navigate("favorites") },
                onHistory = { nav.navigate("history") },
                onSettings = { nav.navigate("settings") },
            )
        }
        composable("favorites") {
            FavoritesScreen(
                onBack = { nav.popBackStack() },
                onChannelClick = { ch -> PlayerHolder.current = ch; nav.navigate("player") },
            )
        }
        composable("history") {
            HistoryScreen(
                onBack = { nav.popBackStack() },
                onChannelClick = { ch -> PlayerHolder.current = ch; nav.navigate("player") },
            )
        }
        composable("player") { PlayerScreen(onBack = { nav.popBackStack() }) }
        composable("settings") { SettingsScreen(onBack = { nav.popBackStack() }) }
    }
}
EOF

cat > app/src/main/java/com/nova/sync/ui/UntrustedScreen.kt << 'EOF'
package com.nova.sync.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.nova.sync.ui.components.TvButton

@Composable
fun UntrustedScreen(
    androidId: String,
    onRecheck: () -> Unit,
    reason: String? = null,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF000000))
            .padding(48.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            "Устройство не доверено",
            color = Color.White,
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
        )
        Spacer(Modifier.height(16.dp))
        Text(
            "Добавь этот ID через Actions → add-device",
            color = Color(0xFF9AA0A6),
        )
        Spacer(Modifier.height(24.dp))
        if (androidId.isNotBlank()) {
            Text(
                androidId,
                color = Color(0xFF7C3AED),
                fontSize = 24.sp,
                fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.SemiBold,
            )
        }
        if (!reason.isNullOrBlank()) {
            Spacer(Modifier.height(12.dp))
            Text("Причина: $reason", color = Color(0xFFEE6666))
        }
        Spacer(Modifier.height(32.dp))
        TvButton(text = "Проверить снова", onClick = onRecheck)
    }
}
EOF

cat > app/src/main/java/com/nova/sync/ui/ChannelsScreen.kt << 'EOF'
package com.nova.sync.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.nova.sync.data.Channel
import com.nova.sync.player.ChannelsViewModel
import com.nova.sync.ui.components.ChannelCard
import com.nova.sync.ui.components.TvButton

@Composable
fun ChannelsScreen(
    onChannelClick: (Channel) -> Unit,
    onFavorites: () -> Unit,
    onHistory: () -> Unit,
    onSettings: () -> Unit,
    vm: ChannelsViewModel = viewModel(),
) {
    val state by vm.state.collectAsStateWithLifecycle()
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(horizontal = 40.dp, vertical = 24.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                "Sync",
                color = Color.White,
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.weight(1f),
            )
            TvButton("Избранное", onFavorites)
            Spacer(Modifier.width(10.dp))
            TvButton("История", onHistory)
            Spacer(Modifier.width(10.dp))
            TvButton("Настройки", onSettings)
        }
        Spacer(Modifier.height(20.dp))

        when {
            state.loading -> Box(Modifier.fillMaxSize(), Alignment.Center) {
                CircularProgressIndicator(color = Color.White)
            }
            state.error != null -> Box(Modifier.fillMaxSize(), Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("Ошибка: ${state.error}", color = Color(0xFFEE6666))
                    Spacer(Modifier.height(16.dp))
                    TvButton("Повторить", vm::load)
                }
            }
            else -> LazyColumn(
                modifier = Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                items(state.channels, key = { it.id }) { ch ->
                    ChannelCard(ch, onClick = { onChannelClick(ch) })
                }
            }
        }
    }
}
EOF

cat > app/src/main/java/com/nova/sync/ui/FavoritesScreen.kt << 'EOF'
package com.nova.sync.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.nova.sync.data.Channel
import com.nova.sync.player.ChannelsViewModel
import com.nova.sync.ui.components.ChannelCard
import com.nova.sync.ui.components.TvButton

@Composable
fun FavoritesScreen(
    onBack: () -> Unit,
    onChannelClick: (Channel) -> Unit,
    vm: ChannelsViewModel = viewModel(),
) {
    val state by vm.state.collectAsStateWithLifecycle()
    val list = state.channels.filter { it.id in state.favorites }
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(40.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                "Избранное",
                color = Color.White,
                style = MaterialTheme.typography.headlineMedium,
                modifier = Modifier.weight(1f),
            )
            TvButton("Назад", onBack)
        }
        Spacer(Modifier.height(20.dp))
        if (list.isEmpty()) {
            Text("Пока ничего не добавлено", color = Color(0xFF9AA0A6))
        } else {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                items(list, key = { it.id }) { ch -> ChannelCard(ch, onClick = { onChannelClick(ch) }) }
            }
        }
    }
}
EOF

cat > app/src/main/java/com/nova/sync/ui/HistoryScreen.kt << 'EOF'
package com.nova.sync.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.nova.sync.data.Channel
import com.nova.sync.data.HistoryStore
import com.nova.sync.player.ChannelsViewModel
import com.nova.sync.ui.components.ChannelCard
import com.nova.sync.ui.components.TvButton

@Composable
fun HistoryScreen(
    onBack: () -> Unit,
    onChannelClick: (Channel) -> Unit,
    vm: ChannelsViewModel = viewModel(),
) {
    val state by vm.state.collectAsStateWithLifecycle()
    val order = HistoryStore.all()
    val map = state.channels.associateBy { it.id }
    val list = order.mapNotNull { map[it] }
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(40.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                "История",
                color = Color.White,
                style = MaterialTheme.typography.headlineMedium,
                modifier = Modifier.weight(1f),
            )
            TvButton("Назад", onBack)
        }
        Spacer(Modifier.height(20.dp))
        if (list.isEmpty()) {
            Text("Пусто", color = Color(0xFF9AA0A6))
        } else {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                items(list, key = { it.id }) { ch -> ChannelCard(ch, onClick = { onChannelClick(ch) }) }
            }
        }
    }
}
EOF

cat > app/src/main/java/com/nova/sync/ui/SettingsScreen.kt << 'EOF'
package com.nova.sync.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.nova.sync.ui.components.TvButton

@Composable
fun SettingsScreen(onBack: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(40.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                "Настройки",
                color = Color.White,
                style = MaterialTheme.typography.headlineMedium,
                modifier = Modifier.weight(1f),
            )
            TvButton("Назад", onBack)
        }
        Spacer(Modifier.height(24.dp))
        Text("Версия 1.0.0", color = Color(0xFF9AA0A6))
        Spacer(Modifier.height(8.dp))
        Text("Плеер: ExoPlayer / HLS", color = Color(0xFF9AA0A6))
        Spacer(Modifier.height(8.dp))
        Text("Источник: Pages / c.json", color = Color(0xFF9AA0A6))
        Spacer(Modifier.height(24.dp))
        Text(
            "Управление:\n" +
            "OK / Enter — пауза / воспроизведение\n" +
            "← → — ±10 секунд\n" +
            "Back — выход к списку",
            color = Color.White,
        )
    }
}
EOF

cat > app/src/main/java/com/nova/sync/ui/PlayerScreen.kt << 'EOF'
package com.nova.sync.ui

import android.view.ViewGroup
import androidx.annotation.OptIn
import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.*
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.PlayerView
import com.nova.sync.data.HistoryStore
import com.nova.sync.data.Resolver
import com.nova.sync.player.PlayerHolder
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@OptIn(UnstableApi::class)
@Composable
fun PlayerScreen(onBack: () -> Unit) {
    val ctx = LocalContext.current
    val channel = PlayerHolder.current
    if (channel == null) {
        LaunchedEffect(Unit) { onBack() }
        return
    }

    val scope = rememberCoroutineScope()
    var resolvedUrl by remember { mutableStateOf<String?>(channel.streamUrl) }
    var resolveError by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(channel.id) {
        if (resolvedUrl.isNullOrBlank() && !channel.blocked) {
            val u = Resolver.resolveStream(channel.id)
            if (u.isNullOrBlank()) resolveError = "Поток недоступен"
            resolvedUrl = u
        }
    }

    val player = remember(channel.id, resolvedUrl) {
        if (resolvedUrl.isNullOrBlank()) null
        else {
            val httpFactory = DefaultHttpDataSource.Factory()
                .setUserAgent(
                    "Mozilla/5.0 (Linux; Android TV) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
                )
                .setAllowCrossProtocolRedirects(true)
                .setConnectTimeoutMs(15_000)
                .setReadTimeoutMs(20_000)
            ExoPlayer.Builder(ctx)
                .setMediaSourceFactory(DefaultMediaSourceFactory(httpFactory))
                .build()
                .apply {
                    setMediaItem(MediaItem.fromUri(resolvedUrl!!))
                    prepare()
                    playWhenReady = true
                }
        }
    }

    DisposableEffect(player) {
        HistoryStore.push(channel.id)
        onDispose { player?.release() }
    }

    var showOsd by remember { mutableStateOf(true) }
    var isPlaying by remember { mutableStateOf(true) }

    LaunchedEffect(showOsd, isPlaying) {
        if (showOsd) { delay(4000); showOsd = false }
    }

    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .focusRequester(focus)
            .focusable()
            .onPreviewKeyEvent { e ->
                if (e.type != KeyEventType.KeyDown) return@onPreviewKeyEvent false
                when (e.key) {
                    Key.DirectionLeft -> {
                        player?.let { it.seekTo((it.currentPosition - 10_000).coerceAtLeast(0)) }
                        showOsd = true; true
                    }
                    Key.DirectionRight -> {
                        player?.let { it.seekTo(it.currentPosition + 10_000) }
                        showOsd = true; true
                    }
                    Key.DirectionCenter, Key.Enter, Key.Spacebar -> {
                        isPlaying = !isPlaying
                        player?.playWhenReady = isPlaying
                        showOsd = true; true
                    }
                    Key.Back -> { onBack(); true }
                    Key.MediaPlayPause -> {
                        isPlaying = !isPlaying
                        player?.playWhenReady = isPlaying
                        true
                    }
                    else -> false
                }
            }
    ) {
        if (player != null) {
            AndroidView(
                factory = { c ->
                    PlayerView(c).apply {
                        this.player = player
                        useController = false
                        keepScreenOn = true
                        layoutParams = ViewGroup.LayoutParams(
                            ViewGroup.LayoutParams.MATCH_PARENT,
                            ViewGroup.LayoutParams.MATCH_PARENT,
                        )
                    }
                },
                modifier = Modifier.fillMaxSize(),
            )
        } else {
            Box(Modifier.fillMaxSize(), Alignment.Center) {
                Text(
                    resolveError ?: "Загрузка...",
                    color = Color.White,
                    style = MaterialTheme.typography.titleLarge,
                )
            }
        }

        if (showOsd) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .align(Alignment.BottomCenter)
                    .background(Color(0xCC000000))
                    .padding(24.dp)
            ) {
                Column(Modifier.weight(1f)) {
                    Text(
                        channel.title.ifBlank { channel.id },
                        color = Color.White,
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                    )
                    Text(
                        if (isPlaying) "▶ OK — пауза · ← → — ±10 сек · Back — выход"
                        else "⏸ OK — продолжить",
                        color = Color(0xFFB8C4D8),
                    )
                }
            }
        }
    }

    // silence unused warning if not consumed
    scope.launch { }
}
EOF

# ============ Python parser ============
cat > scripts/sync.py << 'EOF'
#!/usr/bin/env python3
"""Data sync script. Runs on GitHub Actions schedule."""
import json, time, sys
from datetime import datetime, timezone
try:
    import requests
except ImportError:
    print("ERROR: requests not installed"); sys.exit(1)

UA = ("Mozilla/5.0 (Linux; Android TV) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
BASE = "https://rutube.ru"
HEADERS = {
    "User-Agent": UA, "Referer": "https://rutube.ru/",
    "Origin": "https://rutube.ru", "Accept": "*/*",
    "Accept-Language": "ru-RU,ru;q=0.9,en;q=0.8",
}
TITLE_PREFIX = "Прямой эфир"
CATEGORY_RENAMES = {"Все прямые эфиры": "Прямые эфиры", "Новости и СМИ": "Новости"}
MAX_RETRIES = 3
CHANNEL_DELAY = 0.15
RETRY_DELAY_BASE = 0.5
PERMANENT_ERRORS = {400, 401, 403, 404, 410, 422}
STATS = {"ok": 0, "404": 0, "403": 0, "5xx": 0, "timeout": 0, "other": 0}
OUT = "docs/c.json"

def http_get(url, params=None, timeout=15):
    last_ex = None
    for attempt in range(MAX_RETRIES):
        try:
            r = requests.get(url, params=params, headers=HEADERS, timeout=timeout)
            if r.status_code in PERMANENT_ERRORS:
                raise requests.HTTPError(f"{r.status_code} {r.reason}", response=r)
            r.raise_for_status()
            return r
        except requests.HTTPError as e:
            status = e.response.status_code if e.response is not None else 0
            if status in PERMANENT_ERRORS: raise
            last_ex = e
            if attempt < MAX_RETRIES - 1:
                time.sleep(RETRY_DELAY_BASE * (attempt + 1))
        except (requests.Timeout, requests.ConnectionError) as e:
            last_ex = e
            if attempt < MAX_RETRIES - 1:
                time.sleep(RETRY_DELAY_BASE * (attempt + 1))
        except Exception as e:
            last_ex = e; break
    raise last_ex

def clean_title(s):
    s = s.strip()
    if s.startswith(TITLE_PREFIX):
        rest = s[len(TITLE_PREFIX):].lstrip(" :;,-\u2013\u2014")
        if rest: return rest
    return s

def clean_category(s):
    return CATEGORY_RENAMES.get(s.strip(), s.strip())

def category_text(v):
    if v is None: return ""
    if isinstance(v, str): return v.strip()
    if isinstance(v, dict):
        n = v.get("name"); return str(n).strip() if n else ""
    return str(v).strip()

def description_text(v):
    return v.strip() if isinstance(v, str) else ("" if v is None else str(v).strip())

def fetch_channels():
    url = f"{BASE}/api/feeds/autowidget/2"
    params = {"client": "wdp", "show_hidden_videos": "true",
              "show_user_hidden_videos": "true", "origin__type": "rst,rspa"}
    return http_get(url, params=params).json()

def parse_channels(data):
    out = []; seen = set()
    def add(entry, group=None):
        if not entry: return
        cid = entry.get("id")
        if not cid or cid in seen: return
        title = (entry.get("title") or "").strip()
        if not title: return
        d = entry.get("duration")
        if d is not None and d != 0: return
        if entry.get("origin_type") == "ifrm": return
        seen.add(cid)
        own = category_text(entry.get("category")) or None
        base_group = own or (group.strip() if group else None)
        final_group = clean_category(base_group) if base_group else None
        out.append({"id": cid, "title": clean_title(title),
                    "description": description_text(entry.get("description")),
                    "category": final_group, "avatar": "",
                    "stream_url": None, "blocked": False,
                    "blocked_reason": "", "unavailable": False})
    results = data.get("results")
    if results:
        for e in results:
            ch = e.get("childs")
            if ch:
                for c in ch: add(c, e.get("name"))
            else: add(e)
    else:
        feed = data.get("feed") or {}
        res = feed.get("resources") or []
        if len(res) > 1:
            for it in (res[1].get("items") or []): add(it)
    return out

def is_blocked(resp):
    t = resp.get("type")
    if t in ("blocking_rule", "player_stub"): return True
    d = resp.get("detail")
    if isinstance(d, dict):
        dt = d.get("type")
        if dt in ("blocking_rule", "player_stub"): return True
        n = str(d.get("name") or "")
        if n.startswith("blocking_rule") or n == "login_required": return True
    return False

def blocked_reason(resp):
    d = resp.get("detail") or {}
    if not isinstance(d, dict): d = {}
    n = str(d.get("name") or "")
    t = resp.get("type") or d.get("type")
    if t == "blocking_rule" or n.startswith("blocking_rule"): return "правообладатель или VPN"
    if t == "player_stub" or n == "login_required": return "скрыто автором"
    return "недоступно"

def enrich(ch):
    try:
        r = http_get(f"{BASE}/api/play/options/{ch['id']}/")
        resp = r.json(); STATS["ok"] += 1
    except requests.HTTPError as e:
        s = e.response.status_code if e.response is not None else 0
        if s in (404, 410): STATS["404"] += 1; ch["unavailable"] = True
        elif s == 403: STATS["403"] += 1; ch["unavailable"] = True
        elif 500 <= s < 600: STATS["5xx"] += 1
        else: STATS["other"] += 1
        return
    except (requests.Timeout, requests.ConnectionError):
        STATS["timeout"] += 1; return
    except Exception:
        STATS["other"] += 1; return

    if is_blocked(resp):
        ch["blocked"] = True; ch["blocked_reason"] = blocked_reason(resp); return

    # avatar: prefer thumbnail_url.hq, fallback author.avatar_url
    thumb = resp.get("thumbnail_url")
    if isinstance(thumb, dict):
        ch["avatar"] = thumb.get("hq") or thumb.get("original") or ""
    elif isinstance(thumb, str):
        ch["avatar"] = thumb
    if not ch["avatar"]:
        author = resp.get("author")
        if isinstance(author, dict):
            ch["avatar"] = author.get("avatar_url") or ""

    live = resp.get("live_streams") or {}
    if isinstance(live, dict):
        hls = live.get("hls") or []
        if hls and isinstance(hls, list):
            first = hls[0]
            if isinstance(first, dict):
                ch["stream_url"] = first.get("url")

def main():
    print(f"sync started {datetime.now(timezone.utc).isoformat()}")
    try:
        data = fetch_channels()
    except Exception as e:
        print(f"FATAL: {e}"); sys.exit(1)
    channels = parse_channels(data)
    print(f"got {len(channels)} channels")
    if not channels:
        print("FATAL: no channels"); sys.exit(1)
    for i, ch in enumerate(channels, 1):
        enrich(ch)
        if i % 20 == 0 or i == len(channels):
            print(f"[{i}/{len(channels)}] ok={STATS['ok']} 404={STATS['404']}")
        time.sleep(CHANNEL_DELAY)
    final = [c for c in channels if not c.get("blocked")]
    payload = {
        "updated": datetime.now(timezone.utc).isoformat(),
        "total": len(final),
        "with_url": sum(1 for c in final if c.get("stream_url")),
        "no_url": sum(1 for c in final if not c.get("stream_url")),
        "channels": final,
    }
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
    print(f"saved {OUT} with {len(final)} channels")

if __name__ == "__main__":
    main()
EOF

# ============ docs ============
cat > docs/c.json << 'EOF'
{
  "updated": "1970-01-01T00:00:00+00:00",
  "total": 0,
  "with_url": 0,
  "no_url": 0,
  "channels": []
}
EOF

cat > docs/trusted_devices.json << 'EOF'
{
  "devices": []
}
EOF

touch docs/.nojekyll

# ============ Workflows ============
cat > .github/workflows/build.yml << 'EOF'
name: build
on:
  push:
    branches: [ main ]
    paths-ignore:
      - 'docs/**'
      - 'README.md'
  workflow_dispatch:

permissions:
  contents: write

jobs:
  apk:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
      - uses: android-actions/setup-android@v3
      - name: Ensure gradle wrapper
        run: |
          if [ ! -f gradlew ]; then
            sudo apt-get update && sudo apt-get install -y gradle || true
            gradle wrapper --gradle-version 8.9 --distribution-type all || true
          fi
          chmod +x gradlew || true
      - name: Build
        env:
          SGN_B64: ${{ secrets.SGN_B64 }}
          SGN_P1: ${{ secrets.SGN_P1 }}
          SGN_K: ${{ secrets.SGN_K }}
        run: |
          if [ -z "${SGN_B64:-}" ]; then
            ./gradlew assembleDebug --stacktrace
            mkdir -p out && cp app/build/outputs/apk/debug/*.apk out/App.apk
          else
            ./gradlew assembleRelease --stacktrace
            mkdir -p out && cp app/build/outputs/apk/release/*.apk out/App.apk
          fi
      - uses: softprops/action-gh-release@v2
        with:
          tag_name: latest
          name: "Sync (latest)"
          files: out/App.apk
          make_latest: true
EOF

cat > .github/workflows/sync.yml << 'EOF'
name: sync
on:
  schedule:
    - cron: "15 3 1,15 * *"
  workflow_dispatch:

concurrency:
  group: sync
  cancel-in-progress: false

permissions:
  contents: write

jobs:
  run:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.11' }
      - run: pip install requests
      - run: python scripts/sync.py
      - name: Commit
        run: |
          git config user.name "actions"
          git config user.email "actions@users.noreply.github.com"
          git add docs/c.json || true
          git diff --cached --quiet || git commit -m "sync"
          git push || true
EOF

cat > .github/workflows/add-device.yml << 'EOF'
name: add-device
on:
  workflow_dispatch:
    inputs:
      android_id:
        description: 'ANDROID_ID (hex)'
        required: true

permissions:
  contents: write

jobs:
  add:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Update trusted_devices.json
        env:
          AID: ${{ inputs.android_id }}
        run: |
          python3 - <<PY
          import json, os
          aid = os.environ["AID"].strip()
          with open("docs/trusted_devices.json", "r", encoding="utf-8") as f:
              d = json.load(f)
          if aid not in d.get("devices", []):
              d.setdefault("devices", []).append(aid)
          with open("docs/trusted_devices.json", "w", encoding="utf-8") as f:
              json.dump(d, f, ensure_ascii=False, indent=2)
          print("added", aid)
          PY
      - name: Commit
        run: |
          git config user.name "actions"
          git config user.email "actions@users.noreply.github.com"
          git add docs/trusted_devices.json
          git diff --cached --quiet || git commit -m "add device"
          git push || true
EOF

# ============ .gitignore, README ============
cat > .gitignore << 'EOF'
.gradle/
build/
local.properties
*.iml
.idea/
.kotlin/
keystore.jks
keystore.b64
sgn-secrets.txt
sha.txt
*.jks
*.keystore
.cxx/
EOF

cat > README.md << 'EOF'
# Sync

Sync application data.

Managed via GitHub Actions. See `.github/workflows/`.
EOF

echo
echo "=== setup done ==="
ls -la
EOF

---

## После коммита

**Скажи `setup.sh залит`** — и я дам **второй файл**: workflow `.github/workflows/setup.yml`, который запустит `setup.sh` в Actions и разложит все 40 файлов по местам.

Потом — Actions → build.yml → первый APK.

**Если при копировании setup.sh что-то потеряется** — просто напиши, я перезалью.
