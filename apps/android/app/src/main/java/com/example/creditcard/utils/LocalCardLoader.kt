package com.example.creditcard.utils

import com.example.creditcard.data.SharedCard
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Job
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

/** Loading is not an empty wallet. READY is published only after the local cards are available. */
enum class LocalCardLoadState { LOADING, READY, ERROR, LOCKED }

internal class LocalCardLoader(
    private val scope: CoroutineScope,
    private val isLocked: () -> Boolean,
    private val publishCards: (List<SharedCard>) -> Unit
) {
    private val guard = Any()
    private var generation = 0L
    private var job: Job? = null
    private val _state = MutableStateFlow(LocalCardLoadState.LOADING)
    val state: StateFlow<LocalCardLoadState> = _state

    fun lock(clearPrivateState: () -> Unit) = synchronized(guard) {
        generation++
        job?.cancel()
        job = null
        _state.value = LocalCardLoadState.LOCKED
        clearPrivateState()
    }

    fun load(
        readCards: suspend () -> List<SharedCard>,
        afterReady: suspend (Long, List<SharedCard>) -> Unit,
        onReadError: () -> Unit
    ) = synchronized(guard) {
        if (isLocked() || job?.isActive == true) return@synchronized
        val ticket = ++generation
        _state.value = LocalCardLoadState.LOADING
        job = scope.launch(start = CoroutineStart.LAZY) {
            val cards = try {
                readCards().also { ensureActive() }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (_: Exception) {
                withCurrent(ticket) {
                    _state.value = LocalCardLoadState.ERROR
                    onReadError()
                }
                return@launch
            }
            if (!withCurrent(ticket) {
                    publishCards(cards)
                    _state.value = LocalCardLoadState.READY
                }) return@launch
            // History, credentials and network work must never gate the first local render.
            afterReady(ticket, cards)
        }.also { it.start() }
    }

    fun withCurrent(ticket: Long, action: () -> Unit): Boolean = synchronized(guard) {
        if (ticket != generation || isLocked()) return@synchronized false
        action()
        true
    }

    fun withUnlocked(action: () -> Unit) = synchronized(guard) {
        if (!isLocked() && _state.value != LocalCardLoadState.LOCKED) action()
    }
}
