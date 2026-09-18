package com.example.creditcard.data

import com.example.creditcard.utils.AppJson
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test

class CardFutureFieldsTest {
    private fun fixture(): JsonObject = checkNotNull(javaClass.classLoader?.getResourceAsStream("unknown-fields.json"))
        .bufferedReader().use { AppJson.json.parseToJsonElement(it.readText()).jsonObject }

    @Test fun preservesCardAndImageFieldsThroughEditingAndRoundTrip() {
        val input = fixture()
        val card = AppJson.json.decodeFromJsonElement<SharedCard>(input)
        val edited = card.copy(alias = "edited")
        val encoded = AppJson.json.encodeToJsonElement(edited).jsonObject
        assertEquals(input["futureProgram"], encoded["futureProgram"])
        assertEquals(JsonNull, encoded["futureNull"])
        assertEquals(input["cardImages"]!!.jsonArray[0].jsonObject["futureImage"], encoded["cardImages"]!!.jsonArray[0].jsonObject["futureImage"])
        assertEquals("edited", encoded["alias"]!!.jsonPrimitive.content)
        for (key in listOf("showCVV", "_localOnly", "legacyId", "extraFields")) assertFalse(encoded.containsKey(key))
        for (key in listOf("showCVV", "_localOnly")) assertFalse(encoded["cardImages"]!!.jsonArray[0].jsonObject.containsKey(key))
        assertEquals(edited, AppJson.json.decodeFromString<SharedCard>(AppJson.json.encodeToString(edited)))
    }

    @Test fun knownFieldsCannotBeShadowedEvenWhenDefaultsAreNotEncoded() {
        val card = SharedCard(id = "real", extraFields = mapOf("id" to JsonPrimitive("shadow"), "limit" to JsonPrimitive(999), "constructor" to JsonPrimitive("bad"), "future" to JsonNull))
        val encoded = Json.encodeToJsonElement(card).jsonObject
        assertEquals("real", encoded["id"]!!.jsonPrimitive.content)
        assertFalse(encoded.containsKey("limit"))
        assertFalse(encoded.containsKey("constructor"))
        assertEquals(JsonNull, encoded["future"])
    }

    @Test fun syncRecordRoundTripKeepsFutureFields() {
        val card = AppJson.json.decodeFromJsonElement<SharedCard>(fixture())
        val json = AppJson.json.encodeToString(card)
        assertEquals(card.extraFields, AppJson.json.decodeFromString<SharedCard>(json).extraFields)
        assertEquals(card.cardImages.single().extraFields, AppJson.json.decodeFromString<SharedCard>(json).cardImages.single().extraFields)
    }
}
