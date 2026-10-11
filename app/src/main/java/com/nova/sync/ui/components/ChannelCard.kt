package com.nova.sync.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
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
    var okDownAt by remember { mutableLongStateOf(0L) }
    var longFired by remember { mutableLongStateOf(0L) }

    Card(
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .onPreviewKeyEvent { e ->
                when (e.key) {
                    Key.DirectionCenter, Key.Enter, Key.Spacebar -> {
                        when (e.type) {
                            KeyEventType.KeyDown -> {
                                okDownAt = System.currentTimeMillis()
                                false
                            }
                            KeyEventType.KeyUp -> {
                                val dur = System.currentTimeMillis() - okDownAt
                                if (dur >= 600L) {
                                    longFired = System.currentTimeMillis()
                                    onToggleFav()
                                    true
                                } else {
                                    // если долгое сработало только что — гасим и короткое
                                    if (System.currentTimeMillis() - longFired < 300L) {
                                        true
                                    } else {
                                        false
                                    }
                                }
                            }
                            else -> false
                        }
                    }
                    else -> false
                }
            }
    ) {
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

            Spacer(Modifier.width(12.dp))

            Icon(
                imageVector = if (isFav) Icons.Filled.Star else Icons.Outlined.StarOutline,
                contentDescription = null,
                tint = if (isFav) Color(0xFFFFD24D) else Color(0xFF5A5A5A),
                modifier = Modifier.size(32.dp),
            )
        }
    }
}
