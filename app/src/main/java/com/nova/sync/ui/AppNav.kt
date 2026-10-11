package com.nova.sync.ui

import androidx.compose.runtime.Composable
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.nova.sync.player.PlayerHolder

@Composable
fun AppNav() {
    val nav = rememberNavController()
    NavHost(nav, startDestination = "channels") {
        composable("channels") {
            ChannelsScreen(
                onChannelClick = { ch -> PlayerHolder.current = ch; nav.navigate("player") },
                onFavorites = { nav.navigate("favorites") },
                onHistory = { nav.navigate("history") },
                onSettings = { nav.navigate("settings") },
            )
        }
        composable("favorites") {
            FavoritesScreen(
                onBack = { nav.popBackStack() },
                onChannelClick = { ch -> PlayerHolder.current = ch; nav.navigate("player") },
            )
        }
        composable("history") {
            HistoryScreen(
                onBack = { nav.popBackStack() },
                onChannelClick = { ch -> PlayerHolder.current = ch; nav.navigate("player") },
            )
        }
        composable("player") { PlayerScreen(onBack = { nav.popBackStack() }) }
        composable("settings") { SettingsScreen(onBack = { nav.popBackStack() }) }
    }
}
