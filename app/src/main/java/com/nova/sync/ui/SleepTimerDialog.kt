package com.nova.sync.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.tv.material3.Card
import androidx.tv.material3.ExperimentalTvMaterial3Api

private data class Preset(val label: String, val ms: Long)

private val PRESETS = listOf(
    Preset("1 мин", 60_000L),
    Preset("5 мин", 5 * 60_000L),
    Preset("15 мин", 15 * 60_000L),
    Preset("30 мин", 30 * 60_000L),
    Preset("45 мин", 45 * 60_000L),
    Preset("1 ч", 60 * 60_000L),
    Preset("2 ч", 2 * 60 * 60_000L),
    Preset("4 ч", 4 * 60 * 60_000L),
    Preset("6 ч", 6 * 60 * 60_000L),
    Preset("8 ч", 8 * 60 * 60_000L),
    Preset("12 ч", 12 * 60 * 60_000L),
)

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
fun SleepTimerOverlay(
    onDismiss: () -> Unit,
    onSelect: (Long) -> Unit,
    onCancel: () -> Unit,
) {
    val firstFocus = remember { FocusRequester() }
    LaunchedEffect(Unit) {
        // даём композиции собраться, потом просим фокус
        kotlinx.coroutines.delay(50)
        runCatching { firstFocus.requestFocus() }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xE6000000)),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier
                .background(Color(0xFF141414), RoundedCornerShape(16.dp))
                .padding(28.dp)
                .width(560.dp)
        ) {
            Text(
                "Таймер сна",
                color = Color.White,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
            )
            Spacer(Modifier.height(6.dp))
            Text("Приложение закроется по истечении", color = Color(0xFF9AA0A6))
            Spacer(Modifier.height(20.dp))

            // Ряд 1: 1/5/15 мин — первая кнопка с focusRequester
            Row(
                modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                PresetButton(
                    text = PRESETS[0].label,
                    onClick = { onSelect(PRESETS[0].ms) },
                    modifier = Modifier.weight(1f).focusRequester(firstFocus),
                )
                PresetButton(PRESETS[1].label, { onSelect(PRESETS[1].ms) }, Modifier.weight(1f))
                PresetButton(PRESETS[2].label, { onSelect(PRESETS[2].ms) }, Modifier.weight(1f))
            }

            // Остальные ряды
            for (row in PRESETS.drop(3).chunked(3)) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    for (p in row) {
                        PresetButton(p.label, { onSelect(p.ms) }, Modifier.weight(1f))
                    }
                }
            }

            Spacer(Modifier.height(20.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                PresetButton("Отключить", onCancel, Modifier.weight(1f))
                PresetButton("Закрыть", onDismiss, Modifier.weight(1f))
            }
        }
    }
}

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
private fun PresetButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Card(onClick = onClick, modifier = modifier) {
        Box(
            modifier = Modifier
                .background(Color(0xFF1F1F1F))
                .padding(vertical = 14.dp, horizontal = 12.dp)
                .fillMaxWidth(),
            contentAlignment = Alignment.Center,
        ) {
            Text(text, color = Color.White, fontWeight = FontWeight.Medium)
        }
    }
}

fun formatRemaining(ms: Long): String {
    val total = ms / 1000
    val h = total / 3600
    val m = (total % 3600) / 60
    val s = total % 60
    return when {
        h > 0 -> "%d ч %02d мин".format(h, m)
        m > 0 -> "%d мин %02d сек".format(m, s)
        else -> "%d сек".format(s)
    }
}
