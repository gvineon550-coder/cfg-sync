#!/usr/bin/env bash
set -e

mkdir -p app/src/main/java/com/nova/sync/data
mkdir -p app/src/main/java/com/nova/sync/player
mkdir -p app/src/main/java/com/nova/sync/ui/components
mkdir -p app/src/main/java/com/nova/sync/ui

# ============ 1. Repository.kt — кэш каталога ============
cat > app/src/main/java/com/nova/sync/data/Repository.kt << 'XEOF'
package com.nova.sync.data

import com.nova.sync.NativeStrings
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

object Repository {
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(20, TimeUnit.SECONDS)
        .build()

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    @Volatile private var cached: Catalog? = null

    suspend fun loadCatalog(): Result<Catalog> = withContext(Dispatchers.IO) {
        runCatching {
            val url = NativeStrings.pagesBase + "c.json"
            val req = Request.Builder()
                .url(url)
                .header("User-Agent", NativeStrings.uaMobile)
                .header("Accept", "application/json, text/plain, */*")
                .header("Accept-Language", "ru-RU,ru;q=0.9,en;q=0.8")
                .build()
            client.newCall(req).execute().use { resp ->
                require(resp.isSuccessful) { "HTTP ${resp.code}" }
                val body = resp.body?.string().orEmpty()
                val cat = json.decodeFromString<Catalog>(body)
                cached = cat
                cat
            }
        }
    }

    fun channels(): List<Channel> = cached?.channels ?: emptyList()
    fun channelById(id: String): Channel? = cached?.channels?.firstOrNull { it.id == id }
}
XEOF

# ============ 2. ChannelCard.kt — звезда ============
cat > app/src/main/java/com/nova/sync/ui/components/ChannelCard.kt << 'XEOF'
package com.nova.sync.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.tv.material3.Card
import androidx.tv.material3.ExperimentalTvMaterial3Api
import coil.compose.AsyncImage
import com.nova.sync.data.Channel

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
fun ChannelCard(
    channel: Channel,
    isFav: Boolean,
    onClick: () -> Unit,
    onToggleFav: () -> Unit,
) {
    Card(onClick = onClick, modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(Color(0xFF141414))
                .padding(18.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (channel.avatar.isNotBlank()) {
                AsyncImage(
                    model = channel.avatar,
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .size(112.dp, 63.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(Color.Black),
                )
            } else {
                Box(
                    modifier = Modifier
                        .size(112.dp, 63.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(Color(0xFF2A2A2A))
                )
            }

            Spacer(Modifier.width(18.dp))

            Column(Modifier.weight(1f)) {
                Text(
                    channel.title.ifBlank { channel.id },
                    color = Color.White,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.SemiBold,
                )
                if (!channel.category.isNullOrBlank()) {
                    Spacer(Modifier.height(4.dp))
                    Text(channel.category, color = Color(0xFF9AA0A6))
                }
            }

            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clip(RoundedCornerShape(24.dp))
                    .background(Color(0x22FFFFFF))
                    .clickable { onToggleFav() },
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = if (isFav) Icons.Filled.Star else Icons.Outlined.StarOutline,
                    contentDescription = if (isFav) "Убрать" else "В избранное",
                    tint = if (isFav) Color(0xFFFFD24D) else Color(0xFF9AA0A6),
                )
            }
        }
    }
}
XEOF

# ============ 3. ChannelsScreen.kt ============
cat > app/src/main/java/com/nova/sync/ui/ChannelsScreen.kt << 'XEOF'
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
XEOF

# ============ 4. FavoritesScreen.kt ============
cat > app/src/main/java/com/nova/sync/ui/FavoritesScreen.kt << 'XEOF'
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
import com.nova.sync.player.ChannelsViewModel
import com.nova.sync.ui.components.ChannelCard
import com.nova.sync.ui.components.TvButton

@Composable
fun FavoritesScreen(
    onBack: () -> Unit,
    onChannelClick: (Channel) -> Unit,
    vm: ChannelsViewModel = viewModel(),
) {
    val state by vm.state.collectAsStateWithLifecycle()
    val list = state.channels.filter { it.id in state.favorites }
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(40.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                "Избранное",
                color = Color.White,
                style = MaterialTheme.typography.headlineMedium,
                modifier = Modifier.weight(1f),
            )
            TvButton("Назад", onBack)
        }
        Spacer(Modifier.height(20.dp))
        if (list.isEmpty()) {
            Text("Пока ничего не добавлено", color = Color(0xFF9AA0A6))
        } else {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                items(list, key = { it.id }) { ch ->
                    ChannelCard(
                        channel = ch,
                        isFav = true,
                        onClick = { onChannelClick(ch) },
                        onToggleFav = { vm.toggleFavorite(ch.id) },
                    )
                }
            }
        }
    }
}
XEOF

# ============ 5. HistoryScreen.kt ============
cat > app/src/main/java/com/nova/sync/ui/HistoryScreen.kt << 'XEOF'
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
XEOF

# ============ 6. ChannelsViewModel.kt ============
cat > app/src/main/java/com/nova/sync/player/ChannelsViewModel.kt << 'XEOF'
package com.nova.sync.player

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.nova.sync.data.Channel
import com.nova.sync.data.FavoritesStore
import com.nova.sync.data.Repository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class ChannelsUiState(
    val loading: Boolean = true,
    val error: String? = null,
    val channels: List<Channel> = emptyList(),
    val favorites: Set<String> = emptySet(),
)

class ChannelsViewModel : ViewModel() {
    private val _state = MutableStateFlow(ChannelsUiState())
    val state: StateFlow<ChannelsUiState> = _state.asStateFlow()

    init { load() }

    fun load() {
        _state.value = _state.value.copy(loading = true, error = null)
        viewModelScope.launch {
            Repository.loadCatalog()
                .onSuccess { cat ->
                    _state.value = ChannelsUiState(
                        loading = false,
                        channels = cat.channels,
                        favorites = FavoritesStore.all(),
                    )
                }
                .onFailure { e ->
                    _state.value = _state.value.copy(
                        loading = false,
                        error = e.message ?: "error",
                    )
                }
        }
    }

    fun toggleFavorite(id: String) {
        val favs = FavoritesStore.toggle(id)
        _state.value = _state.value.copy(favorites = favs)
    }
}
XEOF

# ============ 7. SleepTimer.kt ============
cat > app/src/main/java/com/nova/sync/player/SleepTimer.kt << 'XEOF'
package com.nova.sync.player

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

object SleepTimer {
    private val _remaining = MutableStateFlow<Long?>(null)
    val remaining: StateFlow<Long?> = _remaining

    fun set(ms: Long) { _remaining.value = ms.coerceAtLeast(0L) }
    fun cancel() { _remaining.value = null }
    fun isActive(): Boolean = _remaining.value != null

    fun tick(deltaMs: Long): Boolean {
        val cur = _remaining.value ?: return false
        val next = cur - deltaMs
        return if (next <= 0L) {
            _remaining.value = null
            true
        } else {
            _remaining.value = next
            false
        }
    }
}
XEOF

# ============ 8. SleepTimerDialog.kt ============
cat > app/src/main/java/com/nova/sync/ui/SleepTimerDialog.kt << 'XEOF'
package com.nova.sync.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
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
fun SleepTimerDialog(
    onDismiss: () -> Unit,
    onSelect: (Long) -> Unit,
    onCancel: () -> Unit,
) {
    Dialog(onDismissRequest = onDismiss) {
        Card(
            onClick = {},
            modifier = Modifier.onPreviewKeyEvent { e ->
                if (e.type == KeyEventType.KeyDown && e.key == Key.Back) {
                    onDismiss(); true
                } else false
            }
        ) {
            Column(
                modifier = Modifier
                    .background(Color(0xFF141414))
                    .padding(28.dp)
                    .width(520.dp)
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

                for (row in PRESETS.chunked(3)) {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        for (p in row) {
                            PresetButton(
                                text = p.label,
                                onClick = { onSelect(p.ms) },
                                modifier = Modifier.weight(1f),
                            )
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
XEOF

# ============ 9. SettingsScreen.kt ============
cat > app/src/main/java/com/nova/sync/ui/SettingsScreen.kt << 'XEOF'
package com.nova.sync.ui

import android.app.Activity
import androidx.compose.foundation.background
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
            TvButton("Назад", onBack)
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
            TvButton("Настроить") { showSleepDialog = true }
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
            TvButton("Выйти") {
                (ctx as? Activity)?.finishAndRemoveTask()
            }
        }

        Spacer(Modifier.height(40.dp))

        Text("Версия 1.0.0", color = Color(0xFF9AA0A6))
        Spacer(Modifier.height(8.dp))
        Text("Плеер: ExoPlayer / HLS", color = Color(0xFF9AA0A6))
        Spacer(Modifier.height(8.dp))
        Text("Источник: Pages / c.json", color = Color(0xFF9AA0A6))
    }

    if (showSleepDialog) {
        SleepTimerDialog(
            onDismiss = { showSleepDialog = false },
            onSelect = { ms -> SleepTimer.set(ms); showSleepDialog = false },
            onCancel = { SleepTimer.cancel(); showSleepDialog = false },
        )
    }
}
XEOF

# ============ 10. PlayerScreen.kt — без перемотки, ↑→/↓←, wake mode ============
cat > app/src/main/java/com/nova/sync/ui/PlayerScreen.kt << 'XEOF'
package com.nova.sync.ui

import android.view.ViewGroup
import androidx.annotation.OptIn
import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
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
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.PlayerView
import com.nova.sync.NativeStrings
import com.nova.sync.data.HistoryStore
import com.nova.sync.data.Repository
import com.nova.sync.data.Resolver
import com.nova.sync.player.PlayerHolder
import kotlinx.coroutines.delay

@OptIn(UnstableApi::class)
@Composable
fun PlayerScreen(onBack: () -> Unit) {
    val ctx = LocalContext.current
    val list = remember { Repository.channels() }
    val initial = PlayerHolder.current

    if (initial == null || list.isEmpty()) {
        LaunchedEffect(Unit) { onBack() }
        return
    }

    var currentIndex by remember {
        mutableIntStateOf(list.indexOfFirst { it.id == initial.id }.coerceAtLeast(0))
    }
    var currentChannel by remember { mutableStateOf(list[currentIndex]) }

    var resolvedUrl by remember(currentChannel.id) { mutableStateOf(currentChannel.streamUrl) }
    var resolveError by remember(currentChannel.id) { mutableStateOf<String?>(null) }

    LaunchedEffect(currentChannel.id) {
        PlayerHolder.current = currentChannel
        HistoryStore.push(currentChannel.id)
        if (resolvedUrl.isNullOrBlank() && !currentChannel.blocked) {
            val u = Resolver.resolveStream(currentChannel.id)
            if (u.isNullOrBlank()) resolveError = "Поток недоступен"
            resolvedUrl = u
        }
    }

    val player: ExoPlayer? = remember(currentChannel.id, resolvedUrl) {
        val url = resolvedUrl
        if (url.isNullOrBlank()) null
        else {
            val httpFactory = DefaultHttpDataSource.Factory()
                .setUserAgent(NativeStrings.uaMobile)
                .setAllowCrossProtocolRedirects(true)
                .setConnectTimeoutMs(15_000)
                .setReadTimeoutMs(20_000)
            ExoPlayer.Builder(ctx)
                .setMediaSourceFactory(DefaultMediaSourceFactory(httpFactory))
                .build()
                .apply {
                    setWakeMode(C.WAKE_MODE_NETWORK)
                    setMediaItem(MediaItem.fromUri(url))
                    prepare()
                    playWhenReady = true
                }
        }
    }

    DisposableEffect(player) {
        onDispose { player?.release() }
    }

    var showOsd by remember { mutableStateOf(true) }
    var isPlaying by remember { mutableStateOf(true) }
    var showListOverlay by remember { mutableStateOf(false) }
    var overlayIndex by remember { mutableIntStateOf(currentIndex) }
    var okDownAt by remember { mutableLongStateOf(0L) }
    var switchHint by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(showOsd, isPlaying, showListOverlay) {
        if (showOsd && !showListOverlay) {
            delay(4000)
            showOsd = false
        }
    }

    LaunchedEffect(switchHint) {
        if (switchHint != null) {
            delay(1500)
            switchHint = null
        }
    }

    fun switchTo(index: Int) {
        if (index in list.indices) {
            currentIndex = index
            currentChannel = list[index]
            resolvedUrl = currentChannel.streamUrl
            resolveError = null
            switchHint = "${index + 1}/${list.size} · ${currentChannel.title.ifBlank { currentChannel.id }}"
            showOsd = true
            isPlaying = true
        }
    }

    fun prevChannel() { if (currentIndex > 0) switchTo(currentIndex - 1) }
    fun nextChannel() { if (currentIndex < list.size - 1) switchTo(currentIndex + 1) }

    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .focusRequester(focus)
            .focusable()
            .onPreviewKeyEvent { e ->
                when (e.key) {
                    Key.Menu, Key.Guide, Key.Info -> {
                        if (e.type == KeyEventType.KeyDown) {
                            showListOverlay = !showListOverlay
                            overlayIndex = currentIndex
                            true
                        } else false
                    }
                    Key.DirectionUp, Key.DirectionRight -> {
                        if (e.type != KeyEventType.KeyDown) return@onPreviewKeyEvent false
                        if (showListOverlay) {
                            if (overlayIndex < list.size - 1) overlayIndex++
                        } else nextChannel()
                        true
                    }
                    Key.DirectionDown, Key.DirectionLeft -> {
                        if (e.type != KeyEventType.KeyDown) return@onPreviewKeyEvent false
                        if (showListOverlay) {
                            if (overlayIndex > 0) overlayIndex--
                        } else prevChannel()
                        true
                    }
                    Key.DirectionCenter, Key.Enter, Key.Spacebar -> {
                        if (e.type == KeyEventType.KeyDown) {
                            okDownAt = System.currentTimeMillis(); true
                        } else if (e.type == KeyEventType.KeyUp) {
                            val dur = System.currentTimeMillis() - okDownAt
                            if (showListOverlay) {
                                switchTo(overlayIndex); showListOverlay = false
                            } else if (dur > 700L) {
                                showListOverlay = true; overlayIndex = currentIndex
                            } else {
                                isPlaying = !isPlaying
                                player?.playWhenReady = isPlaying
                                showOsd = true
                            }
                            true
                        } else false
                    }
                    Key.Back -> {
                        if (e.type != KeyEventType.KeyDown) return@onPreviewKeyEvent false
                        if (showListOverlay) showListOverlay = false else onBack()
                        true
                    }
                    Key.MediaPlayPause -> {
                        if (e.type != KeyEventType.KeyDown) return@onPreviewKeyEvent false
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

        if (showOsd && !showListOverlay) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .align(Alignment.BottomCenter)
                    .background(Color(0xCC000000))
                    .padding(24.dp)
            ) {
                Column {
                    Text(
                        currentChannel.title.ifBlank { currentChannel.id },
                        color = Color.White,
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                    )
                    Text(
                        if (isPlaying)
                            "OK — пауза · ↑↓ / ←→ — канал · удержание OK — список · Back — выход"
                        else "OK — продолжить",
                        color = Color(0xFFB8C4D8),
                    )
                }
            }
        }

        if (switchHint != null && !showListOverlay) {
            Box(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(24.dp)
                    .background(Color(0xAA000000), RoundedCornerShape(12.dp))
                    .padding(horizontal = 20.dp, vertical = 12.dp)
            ) {
                Text(switchHint!!, color = Color.White, fontWeight = FontWeight.Medium)
            }
        }

        if (showListOverlay) {
            ChannelListOverlay(
                list = list,
                selectedIndex = overlayIndex,
                currentIndex = currentIndex,
            )
        }
    }
}

@Composable
private fun ChannelListOverlay(
    list: List<com.nova.sync.data.Channel>,
    selectedIndex: Int,
    currentIndex: Int,
) {
    val listState = rememberLazyListState()
    LaunchedEffect(selectedIndex) {
        listState.animateScrollToItem(selectedIndex.coerceIn(0, list.size - 1))
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xE6000000))
            .padding(40.dp)
    ) {
        Column(Modifier.fillMaxHeight()) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    "Каналы",
                    color = Color.White,
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f),
                )
                Text("${selectedIndex + 1}/${list.size}", color = Color(0xFF9AA0A6))
            }
            Box(Modifier.height(16.dp))
            LazyColumn(
                state = listState,
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                itemsIndexed(list, key = { _, c -> c.id }) { idx, ch ->
                    val isCurrent = idx == currentIndex
                    val isSelected = idx == selectedIndex
                    val bg = when {
                        isSelected -> Color(0xFF7C3AED)
                        isCurrent -> Color(0xFF2A2A2A)
                        else -> Color(0x14FFFFFF)
                    }
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(8.dp))
                            .background(bg)
                            .padding(horizontal = 16.dp, vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            "${idx + 1}.",
                            color = if (isSelected) Color.White else Color(0xFF9AA0A6),
                            modifier = Modifier.width(48.dp),
                        )
                        Text(
                            ch.title.ifBlank { ch.id },
                            color = Color.White,
                            fontWeight = if (isSelected || isCurrent) FontWeight.SemiBold else FontWeight.Normal,
                            modifier = Modifier.weight(1f),
                        )
                        if (isCurrent) Text("●", color = Color(0xFF7C3AED))
                    }
                }
            }
            Box(Modifier.height(12.dp))
            Text("↑↓ — выбор · OK — включить · Back — закрыть", color = Color(0xFF9AA0A6))
        }
    }
}
XEOF

# ============ 11. MainActivity.kt — keep screen on + таймер ============
cat > app/src/main/java/com/nova/sync/MainActivity.kt << 'XEOF'
package com.nova.sync

import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import com.nova.sync.player.SleepTimer
import com.nova.sync.ui.RootScreen
import com.nova.sync.ui.theme.AppTheme
import kotlinx.coroutines.delay

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        setContent {
            AppTheme {
                LaunchedEffect(Unit) {
                    while (true) {
                        delay(1000L)
                        if (SleepTimer.tick(1000L)) {
                            finishAndRemoveTask()
                        }
                    }
                }
                Box(Modifier.fillMaxSize().background(Color.Black)) {
                    RootScreen()
                }
            }
        }
    }
}
XEOF

echo "=== fix_final applied ==="
ls -la app/src/main/java/com/nova/sync/player/
ls -la app/src/main/java/com/nova/sync/ui/
