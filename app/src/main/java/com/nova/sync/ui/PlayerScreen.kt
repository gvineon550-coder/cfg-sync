package com.nova.sync.ui

import android.content.Context
import android.os.PowerManager
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
import androidx.compose.runtime.rememberCoroutineScope
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
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.PlayerView
import com.nova.sync.NativeStrings
import com.nova.sync.PlayerService
import com.nova.sync.data.HistoryStore
import com.nova.sync.data.Repository
import com.nova.sync.data.Resolver
import com.nova.sync.player.PlayerHolder
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private const val STALE_POSITION_THRESHOLD_MS = 60 * 1000L
private const val WATCHDOG_INTERVAL_MS = 2_000L
private const val WATCHDOG_STALL_THRESHOLD_MS = 12_000L
private const val WATCHDOG_MAX_ATTEMPTS = 5

@OptIn(UnstableApi::class)
@Composable
fun PlayerScreen(onBack: () -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val lifecycleOwner = LocalLifecycleOwner.current
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
    var retryCount by remember(currentChannel.id) { mutableIntStateOf(0) }
    var statusText by remember(currentChannel.id) { mutableStateOf<String?>(null) }
    var userPaused by remember(currentChannel.id) { mutableStateOf(false) }
    var lastPausedAt by remember { mutableLongStateOf(0L) }

    val wakeLock = remember {
        val pm = ctx.getSystemService(Context.POWER_SERVICE) as PowerManager
        pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "nova:playback"
        ).apply { setReferenceCounted(false) }
    }

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

            val loadControl = DefaultLoadControl.Builder()
                .setBufferDurationsMs(30_000, 60_000, 1_000, 2_000)
                .setTargetBufferBytes(C.LENGTH_UNSET)
                .setPrioritizeTimeOverSizeThresholds(true)
                .build()

            ExoPlayer.Builder(ctx)
                .setMediaSourceFactory(DefaultMediaSourceFactory(httpFactory))
                .setLoadControl(loadControl)
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
        if (player == null) return@DisposableEffect onDispose { }
        runCatching { PlayerService.start(ctx) }
        onDispose { runCatching { PlayerService.stop(ctx) } }
    }

    DisposableEffect(player, wakeLock) {
        if (player == null) return@DisposableEffect onDispose { }
        val listener = object : Player.Listener {
            override fun onPlayerError(error: PlaybackException) {
                if (userPaused) return
                if (retryCount < 5) {
                    retryCount++
                    statusText = "Переподключение ($retryCount/5)..."
                    scope.launch {
                        delay(2_000)
                        runCatching {
                            player.seekToDefaultPosition()
                            player.prepare()
                            player.playWhenReady = true
                        }
                    }
                } else {
                    statusText = "Не удалось переподключиться. Переключите канал."
                    runCatching { if (wakeLock.isHeld) wakeLock.release() }
                }
            }

            override fun onPlaybackStateChanged(state: Int) {
                if (state == Player.STATE_READY) {
                    retryCount = 0
                }
            }

            override fun onIsPlayingChanged(isPlaying: Boolean) {
                if (isPlaying) {
                    if (!wakeLock.isHeld) {
                        runCatching { wakeLock.acquire(6 * 60 * 60 * 1000L) }
                    }
                    runCatching { PlayerService.start(ctx) }
                } else {
                    if (wakeLock.isHeld) runCatching { wakeLock.release() }
                }
            }
        }
        player.addListener(listener)
        onDispose {
            player.removeListener(listener)
            player.release()
            runCatching { if (wakeLock.isHeld) wakeLock.release() }
        }
    }

    LaunchedEffect(player, currentChannel.id) {
        if (player == null) return@LaunchedEffect
        var lastPos = -1L
        var badSince = 0L
        var attempts = 0

        while (true) {
            delay(WATCHDOG_INTERVAL_MS)

            if (userPaused) {
                badSince = 0L
                lastPos = -1L
                attempts = 0
                continue
            }

            val playing = player.isPlaying
            val pos = player.currentPosition
            val posAdvancing = pos != lastPos

            if (playing && posAdvancing) {
                badSince = 0L
                lastPos = pos
                attempts = 0
                if (statusText != null) statusText = null
                continue
            }

            if (badSince == 0L) badSince = System.currentTimeMillis()
            val badMs = System.currentTimeMillis() - badSince

            if (badMs >= WATCHDOG_STALL_THRESHOLD_MS) {
                attempts++
                if (attempts > WATCHDOG_MAX_ATTEMPTS) {
                    statusText = "Не удалось восстановить. Переключите канал."
                    break
                }
                statusText = "Перезапуск потока ($attempts/$WATCHDOG_MAX_ATTEMPTS)..."
                runCatching {
                    player.seekToDefaultPosition()
                    player.prepare()
                    player.playWhenReady = true
                }
                badSince = 0L
                lastPos = -1L
            }
        }
    }

    DisposableEffect(player, lifecycleOwner, currentChannel.id) {
        if (player == null) return@DisposableEffect onDispose { }
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_PAUSE -> {
                    lastPausedAt = System.currentTimeMillis()
                    runCatching { player.pause() }
                }
                Lifecycle.Event.ON_RESUME -> {
                    val elapsed = System.currentTimeMillis() - lastPausedAt
                    if (elapsed > STALE_POSITION_THRESHOLD_MS) {
                        statusText = "Синхронизация с эфиром..."
                        runCatching {
                            player.seekToDefaultPosition()
                            player.play()
                        }
                        scope.launch { delay(1500); statusText = null }
                    } else {
                        if (!userPaused) runCatching { player.play() }
                    }
                    runCatching { PlayerService.start(ctx) }
                }
                Lifecycle.Event.ON_STOP -> {
                    runCatching { player.pause() }
                }
                else -> {}
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    var showOsd by remember { mutableStateOf(true) }
    var showListOverlay by remember { mutableStateOf(false) }
    var overlayIndex by remember { mutableIntStateOf(currentIndex) }
    var switchHint by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(showOsd, showListOverlay) {
        if (showOsd && !showListOverlay) { delay(4000); showOsd = false }
    }
    LaunchedEffect(switchHint) {
        if (switchHint != null) { delay(1500); switchHint = null }
    }

    fun switchTo(index: Int) {
        if (index in list.indices) {
            currentIndex = index
            currentChannel = list[index]
            resolvedUrl = currentChannel.streamUrl
            resolveError = null
            retryCount = 0
            statusText = null
            userPaused = false
            lastPausedAt = System.currentTimeMillis()
            switchHint = "${index + 1}/${list.size} · ${currentChannel.title.ifBlank { currentChannel.id }}"
            showOsd = true
        }
    }

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
                    Key.DirectionUp, Key.DirectionLeft -> {
                        if (e.type != KeyEventType.KeyDown) return@onPreviewKeyEvent false
                        if (showListOverlay) { if (overlayIndex > 0) overlayIndex-- }
                        else { if (currentIndex > 0) switchTo(currentIndex - 1) }
                        true
                    }
                    Key.DirectionDown, Key.DirectionRight -> {
                        if (e.type != KeyEventType.KeyDown) return@onPreviewKeyEvent false
                        if (showListOverlay) { if (overlayIndex < list.size - 1) overlayIndex++ }
                        else { if (currentIndex < list.size - 1) switchTo(currentIndex + 1) }
                        true
                    }
                    Key.DirectionCenter, Key.Enter, Key.Spacebar -> {
                        if (e.type != KeyEventType.KeyDown) return@onPreviewKeyEvent false
                        if (showListOverlay) {
                            switchTo(overlayIndex); showListOverlay = false
                        } else {
                            showListOverlay = true; overlayIndex = currentIndex
                        }
                        true
                    }
                    Key.Back -> {
                        if (e.type != KeyEventType.KeyDown) return@onPreviewKeyEvent false
                        if (showListOverlay) showListOverlay = false else onBack()
                        true
                    }
                    Key.MediaPlayPause -> {
                        if (e.type != KeyEventType.KeyDown) return@onPreviewKeyEvent false
                        player?.let {
                            userPaused = it.playWhenReady
                            it.playWhenReady = !it.playWhenReady
                        }
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
                        setShowBuffering(PlayerView.SHOW_BUFFERING_NEVER)
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

        if (statusText != null && !showListOverlay) {
            Box(
                modifier = Modifier
                    .align(Alignment.Center)
                    .background(Color(0xCC000000), RoundedCornerShape(12.dp))
                    .padding(horizontal = 24.dp, vertical = 14.dp)
            ) {
                Text(statusText!!, color = Color.White,
                    style = MaterialTheme.typography.titleMedium)
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
                        "OK — список · ↑↓ ←→ — переключить · Back — выход",
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
            ChannelListOverlay(list = list, selectedIndex = overlayIndex, currentIndex = currentIndex)
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
