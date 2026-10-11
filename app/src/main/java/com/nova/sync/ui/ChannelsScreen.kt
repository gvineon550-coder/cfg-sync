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
