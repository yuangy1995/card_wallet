package com.example.creditcard.utils

import kotlinx.coroutines.CancellationException
import org.junit.Assert.*
import org.junit.Test

class LocalCardLoadSessionTest {
    @Test fun initialStateAndSlowReadAreNotAnEmptyWallet() {
        val session = LocalCardLoadSession { true }
        assertEquals(LocalCardLoadState.NOT_LOADED, session.state.value)
        val token = session.begin()!!
        assertEquals(LocalCardLoadState.LOADING, session.state.value)
        assertNull("Repeated resume/retry must coalesce the in-flight read", session.begin())
        var cards = emptyList<String>()
        assertTrue(session.publish(token, LocalCardLoadState.READY) {
            assertEquals(LocalCardLoadState.LOADING, session.state.value)
            cards = listOf("saved-card")
        })
        assertEquals(listOf("saved-card"), cards)
        assertEquals(LocalCardLoadState.READY, session.state.value)
    }

    @Test fun successfulEmptyReadIsDifferentFromFailure() {
        val session = LocalCardLoadSession { true }
        val failed = session.begin()!!
        session.publish(failed, LocalCardLoadState.FAILED)
        assertEquals(LocalCardLoadState.FAILED, session.state.value)
        val retry = session.begin()!!
        session.publish(retry, LocalCardLoadState.READY)
        assertEquals(LocalCardLoadState.READY, session.state.value)
    }

    @Test fun relockingAndUnlockingRejectsOldSuccessAndOldFailure() {
        var unlocked = true
        var cards = emptyList<String>()
        val session = LocalCardLoadSession { unlocked }
        val old = session.begin()!!
        unlocked = false
        session.invalidate { cards = emptyList() }
        assertNull(session.begin())
        unlocked = true
        val current = session.begin()!!
        assertThrows(CancellationException::class.java) { session.checkCurrent(old) }
        assertFalse(session.publish(old, LocalCardLoadState.READY) { cards = listOf("stale") })
        assertFalse(session.publish(old, LocalCardLoadState.FAILED))
        assertEquals(LocalCardLoadState.LOADING, session.state.value)
        session.publish(current, LocalCardLoadState.READY) { cards = listOf("current") }
        assertEquals(listOf("current"), cards)
    }

    @Test fun lockFlagRejectsPublicationBeforeTheLockCollectorRuns() {
        var unlocked = true
        val session = LocalCardLoadSession { unlocked }
        val token = session.begin()!!
        unlocked = false
        assertFalse(session.publish(token, LocalCardLoadState.READY) { fail("Must not publish") })
        assertThrows(CancellationException::class.java) { session.checkCurrent(token) }
    }

    @Test fun ancillaryHistoryDoesNotChangeReadyState() {
        val session = LocalCardLoadSession { true }
        val token = session.begin()!!
        session.publish(token, LocalCardLoadState.READY)
        assertTrue(session.publish(token) { /* delayed history/config result */ })
        assertEquals(LocalCardLoadState.READY, session.state.value)
        session.invalidate {}
        assertFalse(session.publish(token) { fail("Old history must not refill the locked session") })
    }

    @Test fun failedPublisherNeverMarksDataReady() {
        val session = LocalCardLoadSession { true }
        val token = session.begin()!!
        assertThrows(IllegalStateException::class.java) {
            session.publish(token, LocalCardLoadState.READY) { error("synthetic read failure") }
        }
        assertEquals(LocalCardLoadState.LOADING, session.state.value)
        session.publish(token, LocalCardLoadState.FAILED)
        assertEquals(LocalCardLoadState.FAILED, session.state.value)
    }
}
