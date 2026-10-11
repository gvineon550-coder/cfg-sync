package com.nova.sync.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import com.nova.sync.SignatureGuard
import com.nova.sync.TrustState

@Composable
fun RootScreen() {
    var recheck by remember { mutableIntStateOf(0) }
    var state by remember { mutableStateOf<TrustState?>(null) }
    LaunchedEffect(recheck) { state = SignatureGuard.resolve() }
    Box(Modifier.fillMaxSize().background(Color.Black)) {
        when (val s = state) {
            null -> {}
            is TrustState.Trusted -> AppNav()
            is TrustState.Untrusted -> UntrustedScreen(
                androidId = s.androidId,
                onRecheck = { recheck++ },
            )
            is TrustState.Unreliable -> UntrustedScreen(
                androidId = "",
                onRecheck = { recheck++ },
                reason = s.reason,
            )
        }
    }
}
