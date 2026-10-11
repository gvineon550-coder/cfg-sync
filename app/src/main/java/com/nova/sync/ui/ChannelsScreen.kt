package com.nova.sync.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.nova.sync.data.Channel
import com.nova.sync.player.ChannelsViewModel
import com.nova.sync.ui.components.ChannelCard
import com.nova.sync.ui.components.TvButton
import kotlinx.coroutines.launch

@Composable
fun ChannelsScreen(
    onChannelClick: (Channel) -> Unit,
    onFavorites: () -> Unit,
    onHistory: () -> Unit,
    onSettings: () -> Unit,
    vm: ChannelsViewModel = viewModel(),
) {
    val state by vm.state.collectAsStateWithLifecycle()
    val toolbarFocus = remember { FocusRequester() }
    var focusOnToolbar by remember { mutableStateOf(false) }
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(horizontal = 40.dp, vertical = 24.dp)
            .onPreviewKeyEvent { e ->
                if (e.key == Key.Back && e.type == KeyEventType.KeyDown) {
                    if (focusOnToolbar) {
                        false
                    } else {
                        scope.launch {
                            runCatching { listState.scrollToItem(0) }
                        }
                        runCatching { toolbarFocus.requestFocus() }
                        true
                    }
                } else false
            }
    ) {
        Row(
            modifier = Modifier.onFocusChanged { st ->
                focusOnToolbar = st.hasFocus
            },
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "Sync",
                color = Color.White,
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.weight(1f),
            )
            TvButton(
                text = "Избранное",
                onClick = onFavorites,
                modifier = Modifier.focusRequester(toolbarFocus),
            )
            Spacer(Modifier.width(10.dp))
            TvButton(text = "История", onClick = onHistory)
            Spacer(Modifier.width(10.dp))
            TvButton(text = "Настройки", onClick = onSettings)
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
                    TvButton(text = "Повторить", onClick = vm::load)
                }
            }
            else -> LazyColumn(
                state = listState,
                modifier = Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                items(state.channels, key = { it.id }) { ch ->
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
