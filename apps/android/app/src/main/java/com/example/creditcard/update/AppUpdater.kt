package com.example.creditcard.update

import android.app.Application
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import androidx.core.content.pm.PackageInfoCompat
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.creditcard.R
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.serialization.json.Json
import okhttp3.*
import java.io.File
import java.io.IOException
import java.security.MessageDigest
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

enum class UpdatePhase { IDLE, CHECKING, CURRENT, AVAILABLE, DOWNLOADING, READY, FAILED }

data class UpdateState(
    val phase: UpdatePhase = UpdatePhase.IDLE,
    val release: AppRelease? = null,
    val progress: Int = 0,
    val message: Int? = null,
    val automatic: Boolean = true,
    val showDialog: Boolean = false
)

class AppUpdater(application: Application) : AndroidViewModel(application) {
    private val context = application.applicationContext
    private val preferences = context.getSharedPreferences("app_updates", Context.MODE_PRIVATE)
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS).readTimeout(30, TimeUnit.SECONDS)
        .followSslRedirects(false).build()
    private val json = Json { ignoreUnknownKeys = true }
    private val _state = MutableStateFlow(UpdateState(automatic = preferences.getBoolean("automatic", true)))
    val state = _state.asStateFlow()
    private var job: Job? = null
    @Volatile private var downloadCall: Call? = null
    private val downloadDirectory = File(context.cacheDir, "app_updates")
    private val readyFile = File(downloadDirectory, "update.apk")
    private val partialFile = File(downloadDirectory, "update.part")
    private val installedInfo = context.packageManager.getPackageInfo(context.packageName, signatureFlags())
    val currentVersion: String = installedInfo.versionName.orEmpty()
    private val installedCode = PackageInfoCompat.getLongVersionCode(installedInfo)

    fun setAutomatic(enabled: Boolean) {
        preferences.edit().putBoolean("automatic", enabled).apply()
        _state.update { it.copy(automatic = enabled) }
    }

    fun checkAutomatically() {
        if (!_state.value.automatic || _state.value.phase !in listOf(UpdatePhase.IDLE, UpdatePhase.CURRENT, UpdatePhase.FAILED)) return
        val last = preferences.getLong("last_check", 0)
        if (System.currentTimeMillis() - last < TimeUnit.HOURS.toMillis(24)) return
        check(manual = false)
    }

    fun check(manual: Boolean = true) {
        if (job?.isActive == true) return
        if (_state.value.phase == UpdatePhase.READY) { showDialog(); return }
        _state.update { it.copy(phase = UpdatePhase.CHECKING, message = null) }
        // 失败也节流，避免离线设备反复启动时持续请求；手动检查不受限制。
        preferences.edit().putLong("last_check", System.currentTimeMillis()).apply()
        job = viewModelScope.launch {
            try {
                val candidate = withContext(Dispatchers.IO) {
                    var page = 1
                    var newest: AppRelease? = null
                    do {
                        val request = Request.Builder()
                            .url("https://api.github.com/repos/$UPDATE_REPOSITORY/releases?per_page=100&page=$page")
                            .header("Accept", "application/vnd.github+json")
                            .header("X-GitHub-Api-Version", "2022-11-28")
                            .header("User-Agent", "CardWallet-Android").build()
                        val releases = client.newCall(request).awaitResponse().use { response ->
                            if (!response.isSuccessful) throw IOException("Release check failed")
                            json.decodeFromString<List<GitHubRelease>>(response.body?.string() ?: throw IOException())
                        }
                        val found = selectAndroidRelease(releases, newest?.versionCode ?: installedCode)
                        if (found != null) newest = found
                        page++
                    } while (releases.size == 100)
                    newest
                }
                _state.update {
                    it.copy(phase = if (candidate == null) UpdatePhase.CURRENT else UpdatePhase.AVAILABLE,
                        release = candidate, showDialog = candidate != null, message = null)
                }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (_: Exception) {
                _state.update { it.copy(phase = UpdatePhase.FAILED, message = R.string.update_check_failed,
                    showDialog = manual && it.showDialog) }
            }
        }
    }

    fun download() {
        if (job?.isActive == true) return
        val release = _state.value.release ?: return
        _state.update { it.copy(phase = UpdatePhase.DOWNLOADING, progress = 0, message = null, showDialog = true) }
        job = viewModelScope.launch {
            try {
                withContext(Dispatchers.IO) {
                    downloadDirectory.mkdirs()
                    readyFile.delete()
                    val digest = MessageDigest.getInstance("SHA-256")
                    val call = client.newCall(Request.Builder().url(release.asset.url).build())
                    downloadCall = call
                    call.awaitResponse().use { response ->
                        if (!response.isSuccessful) throw IOException("Download failed")
                        val body = response.body ?: throw IOException()
                        var received = 0L
                        var lastProgress = -1
                        body.byteStream().use { input ->
                            partialFile.outputStream().use { output ->
                                val buffer = ByteArray(64 * 1024)
                                while (true) {
                                    ensureActive()
                                    val count = input.read(buffer)
                                    if (count < 0) break
                                    received += count
                                    if (received > release.asset.size) throw InvalidUpdate()
                                    output.write(buffer, 0, count)
                                    digest.update(buffer, 0, count)
                                    val progress = (received * 100 / release.asset.size).toInt()
                                    if (progress != lastProgress) {
                                        lastProgress = progress
                                        _state.update { it.copy(progress = progress) }
                                    }
                                }
                            }
                        }
                        val hash = digest.digest().joinToString("") { "%02x".format(it) }
                        if (received != release.asset.size || !hash.equals(release.asset.digest?.removePrefix("sha256:"), true)) {
                            throw InvalidUpdate()
                        }
                    }
                    validatePackage(partialFile, release)
                    if (!partialFile.renameTo(readyFile)) throw IOException("Cannot prepare update")
                }
                _state.update { it.copy(phase = UpdatePhase.READY, progress = 100) }
            } catch (cancelled: CancellationException) {
                _state.update { it.copy(phase = UpdatePhase.AVAILABLE, progress = 0) }
                throw cancelled
            } catch (failure: Exception) {
                _state.update { it.copy(phase = UpdatePhase.FAILED, message =
                    if (failure is InvalidUpdate) R.string.update_invalid else R.string.update_download_failed) }
            } finally {
                downloadCall = null
                withContext(NonCancellable + Dispatchers.IO) { partialFile.delete() }
            }
        }
    }

    fun cancelDownload() {
        job?.cancel()
        downloadCall?.cancel()
    }

    override fun onCleared() { downloadCall?.cancel() }
    fun dismissDialog() { _state.update { it.copy(showDialog = false) } }
    fun showDialog() { _state.update { it.copy(showDialog = true) } }

    fun canInstall(): Boolean = Build.VERSION.SDK_INT < 26 || context.packageManager.canRequestPackageInstalls()

    fun permissionIntent() = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${context.packageName}"))

    fun install(activityContext: Context) {
        if (_state.value.phase != UpdatePhase.READY || job?.isActive == true) return
        val release = _state.value.release ?: return
        job = viewModelScope.launch {
            try {
                withContext(Dispatchers.IO) { validatePackage(readyFile, release) }
                val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", readyFile)
                activityContext.startActivity(Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "application/vnd.android.package-archive")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                })
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (failure: Exception) {
                val needsDownload = failure is InvalidUpdate || !readyFile.isFile
                _state.update { it.copy(
                    phase = if (needsDownload) UpdatePhase.FAILED else UpdatePhase.READY,
                    message = if (needsDownload) R.string.update_invalid else R.string.update_install_failed
                ) }
            }
        }
    }

    fun reportPermissionFailure() { _state.update { it.copy(message = R.string.update_install_failed) } }

    @Suppress("DEPRECATION")
    private fun validatePackage(file: File, release: AppRelease) {
        val archive = context.packageManager.getPackageArchiveInfo(file.absolutePath, signatureFlags()) ?: throw InvalidUpdate()
        if (archive.packageName != context.packageName ||
            PackageInfoCompat.getLongVersionCode(archive) != release.versionCode ||
            release.versionCode <= installedCode ||
            signatures(archive).isEmpty() || signatures(archive) != signatures(installedInfo) ||
            (Build.VERSION.SDK_INT >= 24 && (archive.applicationInfo?.minSdkVersion ?: 0) > Build.VERSION.SDK_INT)
        ) throw InvalidUpdate()
    }

    @Suppress("DEPRECATION")
    private fun signatures(info: PackageInfo): Set<String> =
        (if (Build.VERSION.SDK_INT >= 28) info.signingInfo?.apkContentsSigners else info.signatures)
            ?.map { it.toCharsString() }?.toSet().orEmpty()

    private class InvalidUpdate : IOException()
}

@Suppress("DEPRECATION")
private fun signatureFlags(): Int =
    if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES

private suspend fun Call.awaitResponse(): Response = suspendCancellableCoroutine { continuation ->
    continuation.invokeOnCancellation { cancel() }
    enqueue(object : Callback {
        override fun onFailure(call: Call, e: IOException) {
            if (!continuation.isCancelled) continuation.resumeWithException(e)
        }
        override fun onResponse(call: Call, response: Response) {
            continuation.resume(response) { _, value, _ -> value.close() }
        }
    })
}
