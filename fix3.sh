#!/usr/bin/env bash
set -e

mkdir -p app/src/main/java/com/nova/sync/ui

# ============ 1. app/build.gradle.kts — добавить zxing ============
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
    implementation("androidx.compose.material:material-icons-extended")
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
    implementation("com.google.zxing:core:3.5.3")
}
XEOF

# ============ 2. QrUtil.kt ============
cat > app/src/main/java/com/nova/sync/ui/QrUtil.kt << 'XEOF'
package com.nova.sync.ui

import android.graphics.Bitmap
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.QRCodeWriter

fun generateQrBitmap(text: String, size: Int = 512): ImageBitmap? {
    if (text.isBlank()) return null
    return try {
        val hints = mapOf(EncodeHintType.MARGIN to 1)
        val matrix = QRCodeWriter().encode(text, BarcodeFormat.QR_CODE, size, size, hints)
        val pixels = IntArray(size * size)
        val black = android.graphics.Color.BLACK
        val white = android.graphics.Color.WHITE
        for (y in 0 until size) {
            val offset = y * size
            for (x in 0 until size) {
                pixels[offset + x] = if (matrix.get(x, y)) black else white
            }
        }
        val bmp = Bitmap.createBitmap(pixels, size, size, Bitmap.Config.ARGB_8888)
        bmp.asImageBitmap()
    } catch (_: Throwable) {
        null
    }
}
XEOF

# ============ 3. UntrustedScreen.kt — с QR, копированием и тач-кнопками ============
cat > app/src/main/java/com/nova/sync/ui/UntrustedScreen.kt << 'XEOF'
package com.nova.sync.ui

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.Toast
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun UntrustedScreen(
    androidId: String,
    onRecheck: () -> Unit,
    reason: String? = null,
) {
    val ctx = LocalContext.current
    val qr = remember(androidId) { generateQrBitmap(androidId, 512) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(40.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxSize(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (qr != null) {
                Image(
                    bitmap = qr,
                    contentDescription = "QR",
                    modifier = Modifier
                        .size(280.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(Color.White)
                        .padding(8.dp)
                )
                Spacer(Modifier.width(40.dp))
            }

            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.Center,
            ) {
                Text(
                    "Устройство не доверено",
                    color = Color.White,
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                )
                Spacer(Modifier.height(12.dp))
                Text(
                    "Отсканируй QR телефоном или скопируй ID и добавь через Actions → add-device",
                    color = Color(0xFF9AA0A6),
                    style = MaterialTheme.typography.bodyLarge,
                )
                Spacer(Modifier.height(20.dp))

                if (androidId.isNotBlank()) {
                    Text(
                        "ANDROID_ID",
                        color = Color(0xFF9AA0A6),
                        style = MaterialTheme.typography.labelMedium,
                    )
                    Spacer(Modifier.height(6.dp))
                    Text(
                        androidId,
                        color = Color(0xFF7C3AED),
                        fontSize = 22.sp,
                        fontFamily = FontFamily.Monospace,
                        fontWeight = FontWeight.SemiBold,
                    )
                }

                if (!reason.isNullOrBlank()) {
                    Spacer(Modifier.height(12.dp))
                    Text("Причина: $reason", color = Color(0xFFEE6666))
                }

                Spacer(Modifier.height(28.dp))

                Row(verticalAlignment = Alignment.CenterVertically) {
                    if (androidId.isNotBlank()) {
                        Button(
                            onClick = {
                                copyToClipboard(ctx, androidId)
                                Toast.makeText(ctx, "ID скопирован", Toast.LENGTH_SHORT).show()
                            },
                            colors = ButtonDefaults.buttonColors(
                                containerColor = Color(0xFF7C3AED),
                                contentColor = Color.White,
                            ),
                        ) {
                            Text("Копировать ID")
                        }
                        Spacer(Modifier.width(16.dp))
                    }

                    OutlinedButton(
                        onClick = onRecheck,
                        colors = ButtonDefaults.outlinedButtonColors(
                            contentColor = Color.White,
                        ),
                    ) {
                        Text("Проверить снова")
                    }
                }
            }
        }
    }
}

private fun copyToClipboard(ctx: Context, text: String) {
    val cm = ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    cm.setPrimaryClip(ClipData.newPlainText("id", text))
}
XEOF

echo "=== fix3 applied ==="
ls -la app/src/main/java/com/nova/sync/ui/
