package com.example.creditcard.utils

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.example.creditcard.data.CardImageAsset
import com.example.creditcard.data.CardSyncRecord
import com.example.creditcard.data.DatabaseHelper
import com.example.creditcard.data.SharedCard
import com.example.creditcard.data.SyncSnapshot
import java.io.File
import java.io.IOException
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.withTimeout
import okhttp3.mockwebserver.Dispatcher
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.RecordedRequest
import okio.Buffer
import okio.Sink
import okio.Timeout
import okio.buffer
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class SyncUploadTest {
    private val context get() = ApplicationProvider.getApplicationContext<Context>()
    private val key = "synthetic-test-key-only"
    private val directory get() = File(context.cacheDir, "sync-upload")
    private fun snapshot(bytes: Int = 0): SyncSnapshot {
        val card = SharedCard(id = "sample", bank = "测试银行", alias = "测试 \"卡\"", cardNumber = "4111111111111111",
            cardImages = if (bytes > 0) listOf(CardImageAsset(id = "fixture", data = "A".repeat(bytes))) else emptyList())
        return SyncSnapshot(generatedAt = "2026-01-01T00:00:00Z", records = listOf(
            CardSyncRecord(cardId = card.id, changedAt = "2026-01-01T00:00:00Z", state = "active", card = card),
            CardSyncRecord(cardId = "deleted", changedAt = "2026-01-01T00:00:01Z", state = "deleted")))
    }

    @Before fun setup() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
        context.getSharedPreferences("credit_card_sync_prefs", Context.MODE_PRIVATE).edit().clear().commit()
        SyncCoordinator.initLocalData(context)
    }
    @After fun teardown() { Dispatchers.resetMain() }

    @Test fun encryptedFileRoundTripsThroughExistingV4Decoder() {
        val original = snapshot(2 * 1024 * 1024)
        lateinit var file: File
        SyncUpload.prepare(directory, original, key).use { upload ->
            file = upload.file
            val raw = file.readText()
            assertFalse(raw.contains("4111111111111111"))
            val restored = AppJson.json.decodeFromString(SyncSnapshot.serializer(), CryptoManager.decryptSyncEnvelopeV4(raw, key))
            assertEquals(original, restored)
            assertEquals(upload.size, upload.requestBody().contentLength())
        }
        assertFalse(file.exists())
    }

    @Test fun requestBodyCanBeReplayedWithProgressReset() {
        SyncUpload.prepare(directory, snapshot(128 * 1024), key).use { upload ->
            val progress = mutableListOf<Long>()
            val body = upload.requestBody { progress += it }
            val first = Buffer(); val second = Buffer()
            body.writeTo(first); body.writeTo(second)
            assertEquals(first.readByteString(), second.readByteString())
            assertEquals(2, progress.count { it == 0L })
            assertEquals(upload.size, progress.last())
            assertTrue(progress.all { it in 0..upload.size })
        }
    }

    @Test fun largePayloadUploadUsesBoundedWrites() {
        SyncUpload.prepare(directory, snapshot(8 * 1024 * 1024), key).use { upload ->
            var transferred = 0L
            var largest = 0L
            val sink = object : Sink {
                override fun write(source: Buffer, byteCount: Long) {
                    largest = maxOf(largest, byteCount); transferred += byteCount; source.skip(byteCount)
                }
                override fun flush() {}
                override fun close() {}
                override fun timeout() = Timeout.NONE
            }.buffer()
            sink.use { upload.requestBody().writeTo(it) }
            assertEquals(upload.size, transferred)
            assertTrue("Network writes must stay bounded", largest <= 16 * 1024)
        }
    }

    @Test fun cancellationAndUploadFailureDeleteTemporaryFiles() {
        directory.mkdirs()
        val before = directory.listFiles()!!.map { it.name }.toSet()
        try {
            SyncUpload.prepare(directory, snapshot(), key) { throw kotlinx.coroutines.CancellationException("test") }
            fail("Cancellation must propagate")
        } catch (_: kotlinx.coroutines.CancellationException) { }
        assertEquals(before, directory.listFiles()!!.map { it.name }.toSet())
        try {
            SyncUpload.prepare(directory, snapshot(), key).use { throw IOException("test upload failure") }
        } catch (_: IOException) { }
        assertEquals(before, directory.listFiles()!!.map { it.name }.toSet())
    }

    /** Local synthetic WebDAV only: exercise commit -> automatic synchronization -> real HTTP PUT. */
    @Test fun editedCardAutomaticallyUploadsAndKeepsItsData() = withServer { server, dav ->
        configure(server)
        val card = SharedCard(id = "edited", bank = "测试银行", alias = "修改后的卡片", cardNumber = "4111111111111111")
        SyncCoordinator.commitCardChanges(context, listOf(card), emptySet())
        runBlocking { withTimeout(30000) { SyncCoordinator.syncStatus.first { it.type == "success" && !it.isSyncing } } }
        assertEquals(1, dav.puts.get())
        val result = AppJson.json.decodeFromString(SyncSnapshot.serializer(),
            CryptoManager.decryptSyncEnvelopeV4(dav.files.values.single(), key))
        assertEquals(card.alias, result.records.single().card!!.alias)
        assertFalse(SyncCoordinator.syncStatus.value.pending)
        assertTrue(directory.listFiles().orEmpty().isEmpty())
        DatabaseHelper(context).use { assertEquals(card.alias, it.getAllCards().single().alias) }
    }

    @Test fun refusedUploadRetainsPendingChangesAndCanRetry() = withServer { server, dav ->
        configure(server); dav.reject.set(true)
        val card = SharedCard(id = "retry", bank = "测试银行", alias = "保留本机修改")
        SyncCoordinator.commitCardChanges(context, listOf(card), emptySet())
        runBlocking { withTimeout(30000) { SyncCoordinator.syncProgress.first { it.phase == "同步失败" } } }
        assertTrue(SyncCoordinator.syncStatus.value.pending)
        DatabaseHelper(context).use { assertEquals(card.alias, it.getAllCards().single().alias) }
        assertTrue(directory.listFiles().orEmpty().isEmpty())
        dav.reject.set(false)
        runBlocking { SyncCoordinator.synchronize(context, publishLocalChanges = true) }
        assertFalse(SyncCoordinator.syncStatus.value.pending)
        assertEquals("success", SyncCoordinator.syncStatus.value.type)
    }

    private fun configure(server: MockWebServer) {
        SyncCoordinator.saveConfig(context, WebDAVConfig(server.url("/dav/").toString(), "demo", "test", key))
    }
    private fun withServer(test: (MockWebServer, Dav) -> Unit) {
        MockWebServer().use { server ->
            val dav = Dav(); server.dispatcher = dav; server.start(); test(server, dav)
        }
    }
    private class Dav : Dispatcher() {
        val files = ConcurrentHashMap<String, String>()
        val puts = AtomicInteger()
        val reject = AtomicBoolean()
        override fun dispatch(request: RecordedRequest): MockResponse {
            val name = request.requestUrl!!.pathSegments.last()
            return when (request.method) {
                "MKCOL" -> MockResponse().setResponseCode(201)
                "PUT" -> {
                    puts.incrementAndGet()
                    if (reject.get()) MockResponse().setResponseCode(503) else {
                        files[name] = request.body.readUtf8(); MockResponse().setResponseCode(201)
                    }
                }
                "GET" -> files[name]?.let { MockResponse().setBody(it) } ?: MockResponse().setResponseCode(404)
                "DELETE" -> { files.remove(name); MockResponse().setResponseCode(204) }
                "PROPFIND" -> MockResponse().setResponseCode(207).setBody(
                    "<D:multistatus xmlns:D=\"DAV:\">" + files.entries.joinToString("") { (file, data) ->
                        "<D:response><D:href>/dav/credit-card-backup/${java.net.URLEncoder.encode(file, "UTF-8")}</D:href>" +
                            "<D:propstat><D:prop><D:getcontentlength>${data.toByteArray().size}</D:getcontentlength>" +
                            "<D:getlastmodified>Mon, 14 Sep 2026 00:00:00 GMT</D:getlastmodified></D:prop></D:propstat></D:response>"
                    } + "</D:multistatus>")
                else -> MockResponse().setResponseCode(405)
            }
        }
    }
}
