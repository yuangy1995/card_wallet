package com.example.creditcard.utils

import com.example.creditcard.data.SharedCard
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.delay
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.withContext
import org.junit.Assert.*
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class LocalCardLoaderTest {
    private val cards = listOf(SharedCard(id = "local-only", bank = "SyntheticBank"))

    @Test fun slowLocalReadIsLoadingNotAnEmptyWallet() = runTest {
        var visible: List<SharedCard>? = null
        val loader = LocalCardLoader(backgroundScope, { false }) { visible = it }
        loader.load({ delay(15_000); cards }, { _, _ -> }, { fail("Unexpected read error") })
        runCurrent()
        assertEquals(LocalCardLoadState.LOADING, loader.state.value)
        assertNull(visible)
        advanceTimeBy(15_000); runCurrent()
        assertEquals(cards, visible)
        assertEquals(LocalCardLoadState.READY, loader.state.value)
    }

    @Test fun localCardsAppearBeforeSlowHistoryOrNetworkWork() = runTest {
        var visible: List<SharedCard>? = null
        var extrasFinished = false
        val loader = LocalCardLoader(backgroundScope, { false }) { visible = it }
        loader.load({ cards }, { _, _ -> delay(15_000); extrasFinished = true }, {})
        runCurrent()
        assertEquals(cards, visible)
        assertEquals(LocalCardLoadState.READY, loader.state.value)
        assertFalse(extrasFinished)
        advanceTimeBy(15_000); runCurrent()
        assertTrue(extrasFinished)
    }

    @Test fun concurrentRequestsOnlyReadTheDatabaseOnce() = runTest {
        var reads = 0
        val loader = LocalCardLoader(backgroundScope, { false }) {}
        val releaseRead = CompletableDeferred<Unit>()
        repeat(3) { loader.load({ reads++; releaseRead.await(); cards }, { _, _ -> }, {}) }
        runCurrent()
        assertEquals(1, reads)
        releaseRead.complete(Unit); runCurrent()
        assertEquals(LocalCardLoadState.READY, loader.state.value)
    }

    @Test fun failedReadIsRetryableAndDoesNotStartSynchronization() = runTest {
        var publications = 0
        var extras = 0
        var errors = 0
        val loader = LocalCardLoader(backgroundScope, { false }) { publications++ }
        loader.load({ error("Unreadable encrypted fixture") }, { _, _ -> extras++ }, { errors++ })
        runCurrent()
        assertEquals(LocalCardLoadState.ERROR, loader.state.value)
        assertEquals(0, publications); assertEquals(0, extras); assertEquals(1, errors)
        loader.load({ cards }, { _, _ -> extras++ }, { errors++ }); runCurrent()
        assertEquals(LocalCardLoadState.READY, loader.state.value)
        assertEquals(1, publications); assertEquals(1, extras); assertEquals(1, errors)
    }

    @Test fun genuinelyEmptyDatabaseIsReadyOnlyAfterTheRead() = runTest {
        var visible: List<SharedCard>? = null
        val loader = LocalCardLoader(backgroundScope, { false }) { visible = it }
        loader.load({ emptyList() }, { _, _ -> }, {})
        assertEquals(LocalCardLoadState.LOADING, loader.state.value)
        assertNull(visible)
        runCurrent()
        assertEquals(LocalCardLoadState.READY, loader.state.value)
        assertEquals(emptyList<SharedCard>(), visible)
    }

    @Test fun lockDropsCardsAndRejectsOldAuxiliaryResultsAfterReunlock() = runTest {
        var locked = false
        var visible = emptyList<SharedCard>()
        var oldTicket = -1L
        val loader = LocalCardLoader(backgroundScope, { locked }) { visible = it }
        loader.load({ cards }, { ticket, _ -> oldTicket = ticket }, {})
        runCurrent()
        locked = true
        loader.lock { visible = emptyList() }
        assertEquals(LocalCardLoadState.LOCKED, loader.state.value)
        assertTrue(visible.isEmpty())
        locked = false
        val replacement = listOf(SharedCard(id = "new-session"))
        loader.load({ replacement }, { _, _ -> }, {}); runCurrent()
        assertFalse(loader.withCurrent(oldTicket) { visible = cards })
        assertEquals(replacement, visible)
    }

    @Test fun lateNonCancellableReadCannotRepopulateAfterLock() = runTest {
        var locked = false
        var visible = emptyList<SharedCard>()
        var errors = 0
        val loader = LocalCardLoader(backgroundScope, { locked }) { visible = it }
        loader.load({ withContext(NonCancellable) { delay(500); cards } }, { _, _ -> }, { errors++ })
        runCurrent()
        locked = true; loader.lock { visible = emptyList() }
        locked = false
        loader.load({ listOf(SharedCard(id = "fresh")) }, { _, _ -> }, {})
        runCurrent(); advanceTimeBy(500); runCurrent()
        assertEquals("fresh", visible.single().id)
        assertEquals(0, errors)
        assertEquals(LocalCardLoadState.READY, loader.state.value)
    }

    @Test fun lockedSessionCannotLoadOrPublish() = runTest {
        val loader = LocalCardLoader(backgroundScope, { true }) { fail("Private cards published") }
        loader.lock {}
        loader.load({ fail("Database read while locked"); emptyList() }, { _, _ -> }, {})
        loader.withUnlocked { fail("Private state published") }
        runCurrent()
        assertEquals(LocalCardLoadState.LOCKED, loader.state.value)
    }
}
