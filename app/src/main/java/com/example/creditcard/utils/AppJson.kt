package com.example.creditcard.utils

import kotlinx.serialization.json.Json

object AppJson {
    val json: Json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
        encodeDefaults = true
        isLenient = true
    }
}
