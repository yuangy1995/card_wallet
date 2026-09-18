package com.example.creditcard.utils

/** Limits apply only when adding new images, never while reading an existing card or snapshot. */
object CardAttachmentPolicy {
    const val MAX_IMAGES = 12
    const val MAX_SOURCE_BYTES = 10 * 1024 * 1024
    const val MAX_EDGE = 1600
    fun canAppend(existingCount: Int, additionalCount: Int) = existingCount >= 0 && additionalCount >= 0 &&
        existingCount <= MAX_IMAGES && additionalCount <= MAX_IMAGES - existingCount
}
