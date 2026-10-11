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
