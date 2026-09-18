package com.example.creditcard.utils

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import android.util.Base64
import androidx.exifinterface.media.ExifInterface
import com.example.creditcard.data.CardImageAsset
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.ByteArrayInputStream
import java.io.InputStream
import java.util.UUID
import kotlin.math.max

object CardImageCodec {
    const val MAX_COUNT = 20
    const val MAX_INPUT_BYTES = 10 * 1024 * 1024
    const val MAX_STORED_BYTES = 2 * 1024 * 1024
    private const val MAX_EDGE = 1600
    fun canAppend(existing: Int, incoming: Int) = incoming > 0 && existing >= 0 && existing + incoming <= MAX_COUNT
    private const val JPEG_QUALITY = 84
    private const val DATA_URL_PREFIX = "data:image/jpeg;base64,"

    fun fromBitmap(bitmap: Bitmap, source: String, name: String = ""): CardImageAsset? {
        return try {
            val normalized = resizeIfNeeded(bitmap)
            val output = ByteArrayOutputStream()
            val compressed = normalized.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, output)
            if (normalized !== bitmap) {
                normalized.recycle()
            }
            if (!compressed || output.size() > MAX_STORED_BYTES) return null
            CardImageAsset(
                id = UUID.randomUUID().toString(),
                mimeType = "image/jpeg",
                data = DATA_URL_PREFIX + Base64.encodeToString(output.toByteArray(), Base64.NO_WRAP),
                createdAt = System.currentTimeMillis(),
                source = source,
                name = name.ifBlank { "${source}_${System.currentTimeMillis()}.jpg" }
            )
        } catch (e: Exception) {
            null
        }
    }

    private fun readBounded(input: InputStream): ByteArray? {
        val result = ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        while (true) {
            val read = input.read(buffer)
            if (read < 0) break
            if (result.size() + read > MAX_INPUT_BYTES) return null
            result.write(buffer, 0, read)
        }
        return result.toByteArray()
    }

    private fun fromBytes(bytes: ByteArray, source: String, name: String): CardImageAsset? {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
        if (options.outWidth <= 0 || options.outHeight <= 0) return null
        options.inSampleSize = 1
        while (max(options.outWidth, options.outHeight) / options.inSampleSize > MAX_EDGE * 2) options.inSampleSize *= 2
        options.inJustDecodeBounds = false
        val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options) ?: return null
        var normalized = decoded
        try {
            val exif = ExifInterface(ByteArrayInputStream(bytes))
            val matrix = Matrix().apply {
                postRotate(exif.rotationDegrees.toFloat())
                if (exif.isFlipped) postScale(-1f, 1f)
            }
            normalized = Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
            return fromBitmap(normalized, source, name)
        } finally {
            if (normalized !== decoded) normalized.recycle()
            decoded.recycle()
        }
    }

    fun fromUri(context: Context, uri: Uri, source: String = "gallery"): CardImageAsset? = try {
        context.contentResolver.openInputStream(uri)?.use { input ->
            readBounded(input)?.let { fromBytes(it, source, uri.lastPathSegment.orEmpty()) }
        }
    } catch (_: Exception) { null }

    fun fromFile(file: File, source: String = "camera_scan"): CardImageAsset? = try {
        file.inputStream().use { input -> readBounded(input)?.let { fromBytes(it, source, file.name) } }
    } catch (_: Exception) { null }

    fun decodeBitmap(asset: CardImageAsset): Bitmap? {
        return try {
            val base64 = asset.data.substringAfter("base64,", asset.data)
            val bytes = Base64.decode(base64, Base64.DEFAULT)
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        } catch (e: Exception) {
            null
        }
    }

    fun dataByteSize(asset: CardImageAsset): Long {
        val encoded = asset.data.substringAfter("base64,", asset.data)
            .filterNot { it.isWhitespace() }
        if (encoded.isEmpty()) return 0
        val padding = when {
            encoded.endsWith("==") -> 2
            encoded.endsWith("=") -> 1
            else -> 0
        }
        return ((encoded.length.toLong() * 3L / 4L) - padding).coerceAtLeast(0L)
    }

    private fun resizeIfNeeded(bitmap: Bitmap): Bitmap {
        val largestEdge = max(bitmap.width, bitmap.height)
        if (largestEdge <= MAX_EDGE) return bitmap
        val scale = MAX_EDGE.toFloat() / largestEdge.toFloat()
        val width = (bitmap.width * scale).toInt().coerceAtLeast(1)
        val height = (bitmap.height * scale).toInt().coerceAtLeast(1)
        return Bitmap.createScaledBitmap(bitmap, width, height, true)
    }

    private fun rotateFileBitmapIfNeeded(file: File, bitmap: Bitmap): Bitmap {
        val orientation = ExifInterface(file.absolutePath).getAttributeInt(
            ExifInterface.TAG_ORIENTATION,
            ExifInterface.ORIENTATION_NORMAL
        )
        val rotationDegrees = when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> 0f
        }
        if (rotationDegrees == 0f) return bitmap

        val matrix = Matrix().apply { postRotate(rotationDegrees) }
        val rotated = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
        if (rotated !== bitmap) {
            bitmap.recycle()
        }
        return rotated
    }
}
