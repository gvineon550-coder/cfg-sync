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
