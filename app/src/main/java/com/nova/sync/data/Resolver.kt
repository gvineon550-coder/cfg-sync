package com.nova.sync.data

import com.nova.sync.NativeStrings
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

object Resolver {
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(20, TimeUnit.SECONDS)
        .build()

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    suspend fun resolveStream(channelId: String): String? = withContext(Dispatchers.IO) {
        runCatching {
            val tpl = NativeStrings.playOptionsTemplate
            if (tpl.isEmpty()) return@runCatching null
            val url = tpl.replace("%s", channelId)
            val req = Request.Builder()
                .url(url)
                .header("User-Agent", NativeStrings.uaMobile)
                .header("Referer", "https://rutube.ru/")
                .header("Origin", "https://rutube.ru")
                .header("Accept", "*/*")
                .header("Accept-Language", "ru-RU,ru;q=0.9,en;q=0.8")
                .build()
            client.newCall(req).execute().use { resp ->
                require(resp.isSuccessful) { "HTTP ${resp.code}" }
                val body = resp.body?.string().orEmpty()
                val obj = json.parseToJsonElement(body).jsonObject
                val live = obj["live_streams"]?.jsonObject ?: return@runCatching null
                val hls = live["hls"]?.jsonArray ?: return@runCatching null
                val first = hls.firstOrNull()?.jsonObject ?: return@runCatching null
                first["url"]?.jsonPrimitive?.content
            }
        }.getOrNull()
    }
}
