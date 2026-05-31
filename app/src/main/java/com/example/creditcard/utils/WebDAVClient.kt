package com.example.creditcard.utils

import okhttp3.Credentials
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.net.URLEncoder
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.regex.Pattern

/**
 * 备份文件描述模型
 */
data class BackupFile(
    val filename: String,
    val size: Long,
    val lastModified: Long
)

/**
 * 原生 WebDAV 通讯客户端
 * 采用 OkHttp 高效处理网络连接，利用 Regex 鲁棒提取 DAV 目录信息
 */
object WebDAVClient {

    private val client = OkHttpClient.Builder()
        .connectTimeout(15, java.util.concurrent.TimeUnit.SECONDS)
        .readTimeout(15, java.util.concurrent.TimeUnit.SECONDS)
        .writeTimeout(15, java.util.concurrent.TimeUnit.SECONDS)
        .callTimeout(45, java.util.concurrent.TimeUnit.SECONDS)
        .build()

    // 默认的备份目录
    private const val BACKUP_DIR = "credit-card-backup"

    /**
     * 测试 WebDAV 连接是否畅通
     */
    fun testConnection(url: String, user: String, pass: String): Pair<Boolean, String> {
        val cleanUrl = sanitizeUrl(url)
        val credential = Credentials.basic(user, pass)
        
        // 尝试发送 PROPFIND 请求获取根目录或确保备份目录存在
        val request = Request.Builder()
            .url(cleanUrl)
            .method("PROPFIND", "".toRequestBody("text/xml".toMediaType()))
            .header("Authorization", credential)
            .header("Depth", "1")
            .build()

        return try {
            client.newCall(request).execute().use { response ->
                if (response.isSuccessful || response.code == 207) {
                    // 连接成功后，顺便确保备份目录已创建
                    ensureBackupDirExists(cleanUrl, credential)
                    Pair(true, "连接成功")
                } else if (response.code == 401) {
                    Pair(false, "认证失败：用户名或密码错误")
                } else {
                    Pair(false, "连接失败，HTTP 错误码: ${response.code}")
                }
            }
        } catch (e: Exception) {
            Pair(false, "连接失败: ${e.message ?: "未知网络错误"}")
        }
    }

    /**
     * 获取云端备份目录下的所有 JSON 备份文件列表
     */
    fun getBackupList(url: String, user: String, pass: String): List<BackupFile> {
        val cleanUrl = sanitizeUrl(url)
        val credential = Credentials.basic(user, pass)
        ensureBackupDirExists(cleanUrl, credential)

        val dirUrl = backupDirUrl(cleanUrl)
        val request = Request.Builder()
            .url(dirUrl)
            .method("PROPFIND", "".toRequestBody("text/xml".toMediaType()))
            .header("Authorization", credential)
            .header("Depth", "1")
            .build()

        val backupFiles = ArrayList<BackupFile>()
        try {
            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful && response.code != 207) {
                    throw IOException("备份列表读取失败，HTTP ${response.code}")
                }
                val body = response.body?.string() ?: throw IOException("备份列表响应为空")
                
                // 使用极其健壮的正则，切分出每个 response 块
                val responsePattern = Pattern.compile("<[^:]*:response>(.*?)</[^:]*:response>", Pattern.DOTALL)
                val responseMatcher = responsePattern.matcher(body)
                
                while (responseMatcher.find()) {
                    val responseContent = responseMatcher.group(1) ?: continue
                    
                    // 提取 href
                    val hrefPattern = Pattern.compile("<[^:]*:href>(.*?)</[^:]*:href>")
                    val hrefMatcher = hrefPattern.matcher(responseContent)
                    if (!hrefMatcher.find()) continue
                    val rawHref = hrefMatcher.group(1) ?: continue
                    
                    // 解码 URL 并提取文件名
                    val decodedHref = java.net.URLDecoder.decode(rawHref, "UTF-8")
                    val filename = decodedHref.substringAfterLast("/")
                    if (filename.isEmpty() || !filename.endsWith(".json")) continue
                    
                    // 提取大小
                    val sizePattern = Pattern.compile("<[^:]*:getcontentlength>(.*?)</[^:]*:getcontentlength>")
                    val sizeMatcher = sizePattern.matcher(responseContent)
                    val size = if (sizeMatcher.find()) sizeMatcher.group(1)?.toLongOrNull() ?: 0L else 0L
                    
                    // 提取修改时间
                    val modPattern = Pattern.compile("<[^:]*:getlastmodified>(.*?)</[^:]*:getlastmodified>")
                    val modMatcher = modPattern.matcher(responseContent)
                    val lastModified = if (modMatcher.find()) {
                        parseHttpDate(modMatcher.group(1) ?: "")
                    } else {
                        0L
                    }
                    
                    backupFiles.add(BackupFile(filename, size, lastModified))
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            throw IOException("备份列表读取失败: ${e.message ?: "未知网络错误"}", e)
        }

        // 按最后修改时间倒序排列
        return backupFiles.sortedByDescending { it.lastModified }
    }

    fun cancelAll() {
        client.dispatcher.cancelAll()
    }

    /**
     * 上传备份同步快照到云端
     */
    fun uploadSyncSnapshot(url: String, user: String, pass: String, filename: String, encryptedJson: String): Boolean {
        val cleanUrl = sanitizeUrl(url)
        val credential = Credentials.basic(user, pass)
        ensureBackupDirExists(cleanUrl, credential)

        val fileUrl = backupFileUrl(cleanUrl, filename)
        val requestBody = encryptedJson.toRequestBody("text/plain; charset=utf-8".toMediaType())
        val request = Request.Builder()
            .url(fileUrl)
            .put(requestBody)
            .header("Authorization", credential)
            .build()

        return try {
            client.newCall(request).execute().use { response ->
                response.isSuccessful || response.code == 201 || response.code == 204
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    /**
     * 从云端下载备份文件内容
     */
    fun restoreBackup(url: String, user: String, pass: String, filename: String): String? {
        val cleanUrl = sanitizeUrl(url)
        val credential = Credentials.basic(user, pass)

        val fileUrl = backupFileUrl(cleanUrl, filename)
        val request = Request.Builder()
            .url(fileUrl)
            .get()
            .header("Authorization", credential)
            .build()

        return try {
            client.newCall(request).execute().use { response ->
                if (response.isSuccessful) response.body?.string() else null
            }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    /**
     * 从云端删除指定的备份文件
     */
    fun deleteBackup(url: String, user: String, pass: String, filename: String): Boolean {
        val cleanUrl = sanitizeUrl(url)
        val credential = Credentials.basic(user, pass)

        val fileUrl = backupFileUrl(cleanUrl, filename)
        val request = Request.Builder()
            .url(fileUrl)
            .delete()
            .header("Authorization", credential)
            .build()

        return try {
            client.newCall(request).execute().use { response ->
                response.isSuccessful || response.code == 204
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    // ==========================================
    // 内部辅助方法
    // ==========================================

    private fun sanitizeUrl(url: String): String {
        var clean = url.trim()
        if (clean.endsWith("/")) {
            clean = clean.substring(0, clean.length - 1)
        }
        if (clean.endsWith("/$BACKUP_DIR")) {
            clean = clean.removeSuffix("/$BACKUP_DIR")
        }
        return clean
    }

    private fun backupDirUrl(baseUrl: String): String = "$baseUrl/$BACKUP_DIR/"

    private fun backupFileUrl(baseUrl: String, filename: String): String {
        return backupDirUrl(baseUrl) + encodePathSegment(filename)
    }

    private fun encodePathSegment(value: String): String {
        return URLEncoder.encode(value, Charsets.UTF_8.name())
            .replace("+", "%20")
            .replace("%28", "(")
            .replace("%29", ")")
    }

    /**
     * 自动检测并确保云端的 /credit-card-backup 目录存在，如果不存在则进行 MKCOL 创建
     */
    private fun ensureBackupDirExists(baseUrl: String, credential: String) {
        val dirUrl = backupDirUrl(baseUrl)
        
        // 先发 PROPFIND 验证目录是否存在
        val checkRequest = Request.Builder()
            .url(dirUrl)
            .method("PROPFIND", "".toRequestBody("text/xml".toMediaType()))
            .header("Authorization", credential)
            .header("Depth", "0")
            .build()

        try {
            client.newCall(checkRequest).execute().use { response ->
                if (response.code == 404) {
                    // 发送 MKCOL 请求创建目录
                    val mkcolRequest = Request.Builder()
                        .url(dirUrl)
                        .method("MKCOL", null)
                        .header("Authorization", credential)
                        .build()
                    client.newCall(mkcolRequest).execute().use { mkcolRes ->
                        // 目录创建成功
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /**
     * 解析 HTTP 协议中的 GMT 格式修改日期，例如 "Thu, 28 May 2026 11:00:00 GMT"
     */
    private fun parseHttpDate(dateStr: String): Long {
        val formats = arrayOf(
            "EEE, dd MMM yyyy HH:mm:ss z",
            "EEE, dd-MMM-yy HH:mm:ss z",
            "EEE MMM d HH:mm:ss yyyy"
        )
        for (format in formats) {
            try {
                val sdf = SimpleDateFormat(format, Locale.US)
                sdf.timeZone = TimeZone.getTimeZone("GMT")
                val parsed = sdf.parse(dateStr.trim())
                if (parsed != null) return parsed.time
            } catch (e: Exception) {
                // 继续尝试下一种
            }
        }
        return 0L
    }
}
