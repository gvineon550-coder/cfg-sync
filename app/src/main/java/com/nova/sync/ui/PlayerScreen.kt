package com.nova.sync.ui

import android.view.ViewGroup
import androidx.annotation.OptIn
import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.*
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.PlayerView
import com.nova.sync.data.HistoryStore
import com.nova.sync.data.Resolver
import com.nova.sync.player.PlayerHolder
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@OptIn(UnstableApi::class)
@Composable
fun PlayerScreen(onBack: () -> Unit) {
    val ctx = LocalContext.current
    val channel = PlayerHolder.current
    if (channel == null) {
        LaunchedEffect(Unit) { onBack() }
        return
    }

    val scope = rememberCoroutineScope()
    var resolvedUrl by remember { mutableStateOf<String?>(channel.streamUrl) }
    var resolveError by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(channel.id) {
        if (resolvedUrl.isNullOrBlank() && !channel.blocked) {
            val u = Resolver.resolveStream(channel.id)
            if (u.isNullOrBlank()) resolveError = "Поток недоступен"
            resolvedUrl = u
        }
    }

    val player = remember(channel.id, resolvedUrl) {
        if (resolvedUrl.isNullOrBlank()) null
        else {
            val httpFactory = DefaultHttpDataSource.Factory()
                .setUserAgent(
                    "Mozilla/5.0 (Linux; Android TV) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
                )
                .setAllowCrossProtocolRedirects(true)
                .setConnectTimeoutMs(15_000)
                .setReadTimeoutMs(20_000)
            ExoPlayer.Builder(ctx)
                .setMediaSourceFactory(DefaultMediaSourceFactory(httpFactory))
                .build()
                .apply {
                    setMediaItem(MediaItem.fromUri(resolvedUrl!!))
                    prepare()
                    playWhenReady = true
                }
        }
    }

    DisposableEffect(player) {
        HistoryStore.push(channel.id)
        onDispose { player?.release() }
    }

    var showOsd by remember { mutableStateOf(true) }
    var isPlaying by remember { mutableStateOf(true) }

    LaunchedEffect(showOsd, isPlaying) {
        if (showOsd) { delay(4000); showOsd = false }
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
                if (e.type != KeyEventType.KeyDown) return@onPreviewKeyEvent false
                when (e.key) {
                    Key.DirectionLeft -> {
                        player?.let { it.seekTo((it.currentPosition - 10_000).coerceAtLeast(0)) }
                        showOsd = true; true
                    }
                    Key.DirectionRight -> {
                        player?.let { it.seekTo(it.currentPosition + 10_000) }
                        showOsd = true; true
                    }
                    Key.DirectionCenter, Key.Enter, Key.Spacebar -> {
                        isPlaying = !isPlaying
                        player?.playWhenReady = isPlaying
                        showOsd = true; true
                    }
                    Key.Back -> { onBack(); true }
                    Key.MediaPlayPause -> {
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
                        this.player = player
                        useController = false
                        keepScreenOn = true
                        layoutParams = ViewGroup.LayoutParams(
                            ViewGroup.LayoutParams.MATCH_PARENT,
                            ViewGroup.LayoutParams.MATCH_PARENT,
                        )
                    }
                },
                modifier = Modifier.fillMaxSize(),
            )
        } else {
            Box(Modifier.fillMaxSize(), Alignment.Center) {
                Text(
                    resolveError ?: "Загрузка...",
                    color = Color.White,
                    style = MaterialTheme.typography.titleLarge,
                )
            }
        }

        if (showOsd) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .align(Alignment.BottomCenter)
                    .background(Color(0xCC000000))
                    .padding(24.dp)
            ) {
                Column(Modifier.weight(1f)) {
                    Text(
                        channel.title.ifBlank { channel.id },
                        color = Color.White,
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                    )
                    Text(
                        if (isPlaying) "▶ OK — пауза · ← → — ±10 сек · Back — выход"
                        else "⏸ OK — продолжить",
                        color = Color(0xFFB8C4D8),
                    )
                }
            }
        }
    }

    // silence unused warning if not consumed
    scope.launch { }
}
