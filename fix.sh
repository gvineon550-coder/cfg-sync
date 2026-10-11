#!/usr/bin/env bash
set -e

# ============ 1. app/build.gradle.kts ============
cat > app/build.gradle.kts << 'XEOF'
import java.util.Base64

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
                val f = File(project.rootDir, "keystore.jks")
                f.writeBytes(Base64.getDecoder().decode(b64))
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
XEOF

# ============ 2. gradle.properties ============
cat > gradle.properties << 'XEOF'
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
kotlin.code.style=official
android.nonTransitiveRClass=true
XEOF

# ============ 3. app/proguard-rules.pro ============
cat > app/proguard-rules.pro << 'XEOF'
-keep class com.nova.sync.data.** { *; }
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.**
-keepclassmembers class kotlinx.serialization.json.** { *** Companion; }
-keepclasseswithmembers class kotlinx.serialization.json.** {
    kotlinx.serialization.KSerializer serializer(...);
}
-keep,includedescriptorclasses class com.nova.sync.**$$serializer { *; }
-keepclassmembers class com.nova.sync.** { *** Companion; }
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}
-keep class com.nova.sync.NativeStrings { *; }
-keep class com.nova.sync.SignatureGuard { *; }
-dontwarn androidx.compose.**
-keep class com.nova.sync.App { *; }
-keep class com.nova.sync.MainActivity { *; }
XEOF

# ============ 4. SignatureGuard.kt ============
mkdir -p app/src/main/java/com/nova/sync
cat > app/src/main/java/com/nova/sync/SignatureGuard.kt << 'XEOF'
package com.nova.sync

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
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
        System.loadLibrary("sigcheck")
        true
    } catch (_: Throwable) {
        false
    }

    fun init(ctx: Context) {
        appCtx = ctx.applicationContext
    }

    suspend fun resolve(): TrustState {
        val ctx = appCtx ?: return TrustState.Unreliable("no_context")
        val isDebuggable = (ctx.applicationInfo.flags and
                ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (!isDebuggable) {
            val actual = signatureSha256(ctx) ?: return TrustState.Unreliable("no_signature")
            if (!actual.equals(EXPECTED_SHA256, ignoreCase = true)) {
                return TrustState.Unreliable("bad_signature")
            }
            if (loaded && nativeIsTampered()) {
                return TrustState.Unreliable("tampered")
            }
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

    @Suppress("DEPRECATION")
    private fun signatureSha256(ctx: Context): String? = try {
        val pm = ctx.packageManager
        val pkg = pm.getPackageInfo(ctx.packageName, PackageManager.GET_SIGNATURES)
        val sig = pkg.signatures?.firstOrNull() ?: return null
        MessageDigest.getInstance("SHA-256")
            .digest(sig.toByteArray())
            .joinToString("") { "%02x".format(it) }
    } catch (_: Throwable) { null }

    private external fun nativeIsTampered(): Boolean
}
XEOF

# ============ 5. MainActivity.kt ============
cat > app/src/main/java/com/nova/sync/MainActivity.kt << 'XEOF'
package com.nova.sync

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import com.nova.sync.ui.RootScreen
import com.nova.sync.ui.theme.AppTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            AppTheme {
                Box(Modifier.fillMaxSize().background(Color.Black)) {
                    RootScreen()
                }
            }
        }
    }
}
XEOF

# ============ 6. PlayerScreen.kt ============
mkdir -p app/src/main/java/com/nova/sync/ui
cat > app/src/main/java/com/nova/sync/ui/PlayerScreen.kt << 'XEOF'
package com.nova.sync.ui

import android.view.ViewGroup
import androidx.annotation.OptIn
import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
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

@OptIn(UnstableApi::class)
@Composable
fun PlayerScreen(onBack: () -> Unit) {
    val ctx = LocalContext.current
    val channel = PlayerHolder.current
    if (channel == null) {
        LaunchedEffect(Unit) { onBack() }
        return
    }

    var resolvedUrl by remember { mutableStateOf(channel.streamUrl) }
    var resolveError by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(channel.id) {
        if (resolvedUrl.isNullOrBlank() && !channel.blocked) {
            val u = Resolver.resolveStream(channel.id)
            if (u.isNullOrBlank()) resolveError = "Поток недоступен"
            resolvedUrl = u
        }
    }

    val player: ExoPlayer? = remember(channel.id, resolvedUrl) {
        val url = resolvedUrl
        if (url.isNullOrBlank()) null
        else {
            val httpFactory = DefaultHttpDataSource.Factory()
                .setUserAgent("Mozilla/5.0 (Linux; Android TV) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
                .setAllowCrossProtocolRedirects(true)
                .setConnectTimeoutMs(15_000)
                .setReadTimeoutMs(20_000)
            ExoPlayer.Builder(ctx)
                .setMediaSourceFactory(DefaultMediaSourceFactory(httpFactory))
                .build()
                .apply {
                    setMediaItem(MediaItem.fromUri(url))
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
                        useController = false
                        keepScreenOn = true
                        layoutParams = ViewGroup.LayoutParams(
                            ViewGroup.LayoutParams.MATCH_PARENT,
                            ViewGroup.LayoutParams.MATCH_PARENT,
                        )
                    }
                },
                update = { view -> view.player = player },
                modifier = Modifier.fillMaxSize(),
            )
        } else {
            Box(Modifier.fillMaxSize(), Alignment.Center) {
                Text(resolveError ?: "Загрузка...", color = Color.White,
                    style = MaterialTheme.typography.titleLarge)
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
                Column {
                    Text(channel.title.ifBlank { channel.id }, color = Color.White,
                        style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    Text(
                        if (isPlaying) "OK — пауза / ← → — ±10 сек / Back — выход"
                        else "OK — продолжить",
                        color = Color(0xFFB8C4D8)
                    )
                }
            }
        }
    }
}
XEOF

# ============ 7. Иконки без градиента ============
cat > app/src/main/res/drawable/ic_launcher_background.xml << 'XEOF'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path android:fillColor="#4F46E5"
        android:pathData="M0,0h108v108h-108z"/>
</vector>
XEOF

cat > app/src/main/res/drawable/banner.xml << 'XEOF'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="320dp"
    android:height="180dp"
    android:viewportWidth="320"
    android:viewportHeight="180">
    <path android:fillColor="#4F46E5"
        android:pathData="M0,0h320v180h-320z"/>
    <group android:translateX="122" android:translateY="52">
        <group android:scaleX="3" android:scaleY="3">
            <path android:fillColor="#FFFFFF"
                android:pathData="M12,4V1L8,5l4,4V6c3.31,0 6,2.69 6,6 0,1.01 -0.25,1.97 -0.7,2.8l1.46,1.46C19.54,15.03 20,13.57 20,12c0,-4.42 -3.58,-8 -8,-8zM12,18c-3.31,0 -6,-2.69 -6,-6 0,-1.01 0.25,-1.97 0.7,-2.8L5.24,7.74C4.46,8.97 4,10.43 4,12c0,4.42 3.58,8 8,8v3l4,-4 -4,-4v3z"/>
        </group>
    </group>
</vector>
XEOF

cat > app/src/main/res/mipmap-anydpi/ic_launcher.xml << 'XEOF'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path android:fillColor="#4F46E5"
        android:pathData="M0,0h108v108h-108z"/>
    <group android:scaleX="2.4" android:scaleY="2.4"
           android:translateX="25.2" android:translateY="25.2">
        <path android:fillColor="#FFFFFF"
            android:pathData="M12,4V1L8,5l4,4V6c3.31,0 6,2.69 6,6 0,1.01 -0.25,1.97 -0.7,2.8l1.46,1.46C19.54,15.03 20,13.57 20,12c0,-4.42 -3.58,-8 -8,-8zM12,18c-3.31,0 -6,-2.69 -6,-6 0,-1.01 0.25,-1.97 0.7,-2.8L5.24,7.74C4.46,8.97 4,10.43 4,12c0,4.42 3.58,8 8,8v3l4,-4 -4,-4v3z"/>
    </group>
</vector>
XEOF

cat > app/src/main/res/mipmap-anydpi/ic_launcher_round.xml << 'XEOF'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path android:fillColor="#4F46E5"
        android:pathData="M0,0h108v108h-108z"/>
    <group android:scaleX="2.4" android:scaleY="2.4"
           android:translateX="25.2" android:translateY="25.2">
        <path android:fillColor="#FFFFFF"
            android:pathData="M12,4V1L8,5l4,4V6c3.31,0 6,2.69 6,6 0,1.01 -0.25,1.97 -0.7,2.8l1.46,1.46C19.54,15.03 20,13.57 20,12c0,-4.42 -3.58,-8 -8,-8zM12,18c-3.31,0 -6,-2.69 -6,-6 0,-1.01 0.25,-1.97 0.7,-2.8L5.24,7.74C4.46,8.97 4,10.43 4,12c0,4.42 3.58,8 8,8v3l4,-4 -4,-4v3z"/>
    </group>
</vector>
XEOF

# ============ 8. build.yml ============
mkdir -p .github/workflows
cat > .github/workflows/build.yml << 'XEOF'
name: build
on:
  push:
    branches: [ main ]
    paths:
      - 'app/**'
      - 'build.gradle.kts'
      - 'settings.gradle.kts'
      - 'gradle.properties'
      - '.github/workflows/build.yml'
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
      - uses: gradle/actions/setup-gradle@v4
        with:
          gradle-version: '8.9'
      - name: Ensure gradle wrapper
        run: |
          if [ ! -f gradlew ]; then
            gradle wrapper --gradle-version 8.9 --distribution-type all
          fi
          chmod +x gradlew
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
XEOF

echo "=== fix applied ==="
ls -la
