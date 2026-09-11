package com.example.creditcard.update

import kotlinx.serialization.json.Json
import org.junit.Assert.*
import org.junit.Test

class GitHubReleaseTest {
    private fun release(code: Long, version: String = "1.1.0"): GitHubRelease {
        val tag = "android-v$version-$code"
        val name = "CardWallet-Android-$code.apk"
        return GitHubRelease(tag = tag, assets = listOf(GitHubAsset(
            name, "https://github.com/$UPDATE_REPOSITORY/releases/download/$tag/$name",
            123456, "sha256:" + "a".repeat(64)
        )))
    }

    @Test fun selectsHighestNumericCodeRegardlessOfOrder() {
        assertEquals(100L, selectAndroidRelease(listOf(release(9), release(100), release(10)), 2)?.versionCode)
    }

    @Test fun ignoresInstalledAndOlderVersions() {
        assertNull(selectAndroidRelease(listOf(release(2), release(1)), 2))
    }

    @Test fun ignoresMacDraftsAndPrereleases() {
        val mac = release(200).copy(tag = "mac-v1.0.0-200")
        assertEquals(3L, selectAndroidRelease(listOf(
            mac, release(100).copy(draft = true), release(90).copy(prerelease = true), release(3)
        ), 2)?.versionCode)
    }

    @Test fun requiresMatchingAssetAndTagVersionCodes() {
        assertNull(selectAndroidRelease(listOf(release(3).copy(tag = "android-v1.1.0-4")), 2))
    }

    @Test fun requiresOfficialHttpsAssetWithValidDigest() {
        val valid = release(3)
        val asset = valid.assets.single()
        listOf(
            asset.copy(url = asset.url.replace("https:", "http:")),
            asset.copy(url = asset.url.replace("github.com", "github.com.evil.test")),
            asset.copy(url = asset.url.replace(UPDATE_REPOSITORY, "another/repo")),
            asset.copy(url = asset.url + "?redirect=elsewhere"),
            asset.copy(digest = null),
            asset.copy(digest = "sha256:bad"),
            asset.copy(size = 0),
            asset.copy(name = "CardWallet-Mac.zip")
        ).forEach { invalid ->
            assertNull(selectAndroidRelease(listOf(valid.copy(assets = listOf(invalid))), 2))
        }
    }

    @Test fun ignoresUnrelatedAssetsAndAcceptsNullNotes() {
        val valid = release(3)
        val candidate = selectAndroidRelease(listOf(valid.copy(body = null, assets = valid.assets +
            GitHubAsset("appcast.xml", "https://example.com/appcast.xml", 300))), 2)
        assertEquals("1.1.0", candidate?.versionName)
        assertEquals("", candidate?.notes)
    }

    @Test fun decodesGitHubPayloadWithExtraFields() {
        val json = """[{"tag_name":"mac-v1.0.0-2","id":123,"body":null,"assets":[],"author":{"login":"test"}}]"""
        val decoded = Json { ignoreUnknownKeys = true }.decodeFromString<List<GitHubRelease>>(json)
        assertNull(selectAndroidRelease(decoded, 1))
    }

    @Test fun ignoresMalformedAndOverflowingVersionCodes() {
        val invalid = release(3).copy(tag = "android-v1.1.0-99999999999999999999999999999")
        assertNull(selectAndroidRelease(listOf(invalid), 2))
        assertNull(selectAndroidRelease(listOf(release(3).copy(tag = "android-vnightly-3")), 2))
    }
}
