package com.nova.sync.ui

import android.app.Activity
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.nova.sync.player.SleepTimer
import com.nova.sync.ui.components.TvButton

@Composable
fun SettingsScreen(onBack: () -> Unit) {
    val ctx = LocalContext.current
    var showSleepDialog by remember { mutableStateOf(false) }
    val remaining by SleepTimer.remaining.collectAsStateWithLifecycle()

    Box(Modifier.fillMaxSize()) {
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
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f),
                )
                TvButton(text = "Назад", onClick = onBack)
            }

            Spacer(Modifier.height(32.dp))

            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(
                        "Таймер сна",
                        color = Color.White,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Text(
                        remaining?.let { "Осталось: ${formatRemaining(it)}" } ?: "Выключен",
                        color = Color(0xFF9AA0A6),
                    )
                }
                TvButton(text = "Настроить", onClick = { showSleepDialog = true })
            }

            Spacer(Modifier.height(20.dp))

            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(
                        "Выйти из приложения",
                        color = Color.White,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Text("Полностью закрыть приложение", color = Color(0xFF9AA0A6))
                }
                TvButton(
                    text = "Выйти",
                    onClick = { (ctx as? Activity)?.finishAndRemoveTask() },
                )
            }

            Spacer(Modifier.height(40.dp))

            Text("Версия 1.0.0", color = Color(0xFF9AA0A6))
            Spacer(Modifier.height(8.dp))
            Text("Плеер: ExoPlayer / HLS", color = Color(0xFF9AA0A6))
            Spacer(Modifier.height(8.dp))
            Text("Источник: Pages / c.json", color = Color(0xFF9AA0A6))
        }

        if (showSleepDialog) {
            SleepTimerOverlay(
                onDismiss = { showSleepDialog = false },
                onSelect = { ms -> SleepTimer.set(ms); showSleepDialog = false },
                onCancel = { SleepTimer.cancel(); showSleepDialog = false },
            )
        }
    }
}
