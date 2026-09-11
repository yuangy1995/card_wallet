package com.example.creditcard.update

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull

const val UPDATE_REPOSITORY = "yuangy1995/card-wallet-releases"

@Serializable
data class GitHubRelease(
    @SerialName("tag_name") val tag: String,
    val draft: Boolean = false,
    val prerelease: Boolean = false,
    val body: String? = null,
    val assets: List<GitHubAsset> = emptyList()
)

@Serializable
data class GitHubAsset(
    val name: String,
    @SerialName("browser_download_url") val url: String,
    val size: Long,
    val digest: String? = null
)

data class AppRelease(
    val versionCode: Long,
    val versionName: String,
    val notes: String,
    val asset: GitHubAsset
)

/** 不依赖发布时间或字符串排序；Mac、草稿和预发布均不参与 Android 升级。 */
fun selectAndroidRelease(releases: List<GitHubRelease>, installedCode: Long): AppRelease? =
    releases.asSequence()
        .filter { !it.draft && !it.prerelease && it.tag.matches(Regex("android-v[0-9]+(\\.[0-9]+){1,2}-[0-9]+")) }
        .flatMap { release ->
            release.assets.mapNotNull { asset ->
                val code = Regex("CardWallet-Android-([0-9]+)\\.apk").matchEntire(asset.name)
                    ?.groupValues?.get(1)?.toLongOrNull() ?: return@mapNotNull null
                val url = asset.url.toHttpUrlOrNull() ?: return@mapNotNull null
                val expectedPath = "/$UPDATE_REPOSITORY/releases/download/${release.tag}/${asset.name}"
                if (code <= installedCode || code.toString() != release.tag.substringAfterLast('-') ||
                    asset.size <= 0 || url.scheme != "https" || url.host != "github.com" ||
                    url.port != 443 || url.username.isNotEmpty() || url.password.isNotEmpty() ||
                    url.encodedPath != expectedPath || url.query != null || url.fragment != null ||
                    asset.digest?.matches(Regex("sha256:[a-fA-F0-9]{64}")) != true
                ) return@mapNotNull null
                AppRelease(code, release.tag.removePrefix("android-v").substringBeforeLast('-'),
                    release.body.orEmpty(), asset)
            }.asSequence()
        }.maxByOrNull { it.versionCode }
