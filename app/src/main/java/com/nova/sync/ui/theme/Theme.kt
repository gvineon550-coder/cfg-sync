package com.nova.sync.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val Colors = darkColorScheme(
    primary = Color(0xFF7C3AED),
    onPrimary = Color.White,
    background = Color(0xFF000000),
    onBackground = Color.White,
    surface = Color(0xFF141414),
    onSurface = Color.White,
)

@Composable
fun AppTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = Colors, content = content)
}
