package com.example.creditcard.utils

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Base64
import com.example.creditcard.data.CardImageAsset
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.UUID
import kotlin.math.max

object CardImageCodec {
    private const val MAX_EDGE = 1600
    private const val JPEG_QUALITY = 84
    private const val DATA_URL_PREFIX = "data:image/jpeg;base64,"

    fun fromBitmap(bitmap: Bitmap, source: String, name: String = ""): CardImageAsset? {
        return try {
            val normalized = resizeIfNeeded(bitmap)
            val output = ByteArrayOutputStream()
            normalized.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, output)
            if (normalized !== bitmap) {
                normalized.recycle()
            }
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

    fun fromUri(context: Context, uri: Uri, source: String = "gallery"): CardImageAsset? {
        return try {
            context.contentResolver.openInputStream(uri)?.use { input ->
                val bitmap = BitmapFactory.decodeStream(input) ?: return null
                fromBitmap(bitmap, source, uri.lastPathSegment ?: "")
            }
        } catch (e: Exception) {
            null
        }
    }

    fun fromFile(file: File, source: String = "camera_scan"): CardImageAsset? {
        return try {
            val bitmap = BitmapFactory.decodeFile(file.absolutePath) ?: return null
            fromBitmap(bitmap, source, file.name)
        } catch (e: Exception) {
            null
        }
    }

    fun decodeBitmap(asset: CardImageAsset): Bitmap? {
        return try {
            val base64 = asset.data.substringAfter("base64,", asset.data)
            val bytes = Base64.decode(base64, Base64.DEFAULT)
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        } catch (e: Exception) {
            null
        }
    }

    private fun resizeIfNeeded(bitmap: Bitmap): Bitmap {
        val largestEdge = max(bitmap.width, bitmap.height)
        if (largestEdge <= MAX_EDGE) return bitmap
        val scale = MAX_EDGE.toFloat() / largestEdge.toFloat()
        val width = (bitmap.width * scale).toInt().coerceAtLeast(1)
        val height = (bitmap.height * scale).toInt().coerceAtLeast(1)
        return Bitmap.createScaledBitmap(bitmap, width, height, true)
    }
}
