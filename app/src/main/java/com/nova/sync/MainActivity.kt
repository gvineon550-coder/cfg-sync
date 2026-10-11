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
