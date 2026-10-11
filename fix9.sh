#!/usr/bin/env bash
set -e

mkdir -p app/src/main/java/com/nova/sync/ui/components

cat > app/src/main/java/com/nova/sync/ui/components/ChannelCard.kt << 'XEOF'
package com.nova.sync.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
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
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // === Основная карточка — открывает канал ===
        Card(
            onClick = onClick,
            modifier = Modifier.weight(1f),
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
            }
        }

        Spacer(Modifier.width(10.dp))

        // === Карточка звезды — toggle favorite ===
        Card(
            onClick = onToggleFav,
            modifier = Modifier.size(72.dp),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color(0xFF141414)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = if (isFav) Icons.Filled.Star else Icons.Outlined.StarOutline,
                    contentDescription = if (isFav) "Убрать" else "В избранное",
                    tint = if (isFav) Color(0xFFFFD24D) else Color(0xFF9AA0A6),
                    modifier = Modifier.size(36.dp),
                )
            }
        }
    }
}
XEOF

echo "=== fix9 applied ==="
ls -la app/src/main/java/com/nova/sync/ui/components/ChannelCard.kt
