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
