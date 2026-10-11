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
