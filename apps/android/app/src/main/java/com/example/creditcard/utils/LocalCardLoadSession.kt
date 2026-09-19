package com.example.creditcard.utils

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

enum class LocalCardLoadState { NOT_LOADED, LOADING, READY, FAILED }

/** A lock cycle invalidates every older reader, even if the app has already unlocked again. */
internal class LocalCardLoadSession(private val canRead: () -> Boolean) {
    private val monitor = Any()
    private var generation = 0L
    private val _state = MutableStateFlow(LocalCardLoadState.NOT_LOADED)
    val state = _state.asStateFlow()

    fun begin(): Long? = synchronized(monitor) {
        if (!canRead() || _state.value == LocalCardLoadState.LOADING) return@synchronized null
        generation += 1
        _state.value = LocalCardLoadState.LOADING
        generation
    }

    fun checkCurrent(token: Long) = synchronized(monitor) {
        if (!isCurrent(token)) throw CancellationException("Local card read was superseded")
    }

    /** Publish cards before READY; observers must never see a ready-but-unpopulated wallet. */
    fun publish(token: Long, next: LocalCardLoadState? = null, action: () -> Unit = {}): Boolean =
        synchronized(monitor) {
            if (!isCurrent(token)) return@synchronized false
            action()
            if (next != null) _state.value = next
            true
        }

    fun invalidate(clear: () -> Unit) = synchronized(monitor) {
        generation += 1
        _state.value = LocalCardLoadState.NOT_LOADED
        clear()
    }

    private fun isCurrent(token: Long): Boolean =
        generation == token && canRead() && _state.value != LocalCardLoadState.NOT_LOADED
}
