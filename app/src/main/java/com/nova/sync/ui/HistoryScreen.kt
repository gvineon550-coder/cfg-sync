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
                items(list, key = { it.id }) { ch ->
                    ChannelCard(
                        channel = ch,
                        isFav = ch.id in state.favorites,
                        onClick = { onChannelClick(ch) },
                        onToggleFav = { vm.toggleFavorite(ch.id) },
                    )
                }
            }
        }
    }
}
