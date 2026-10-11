package com.nova.sync.data

import com.nova.sync.NativeStrings
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

object Repository {
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(20, TimeUnit.SECONDS)
        .build()

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    @Volatile private var cached: Catalog? = null

    suspend fun loadCatalog(): Result<Catalog> = withContext(Dispatchers.IO) {
        runCatching {
            val url = NativeStrings.pagesBase + "c.json"
            val req = Request.Builder()
                .url(url)
                .header("User-Agent", NativeStrings.uaMobile)
                .header("Accept", "application/json, text/plain, */*")
                .header("Accept-Language", "ru-RU,ru;q=0.9,en;q=0.8")
                .build()
            client.newCall(req).execute().use { resp ->
                require(resp.isSuccessful) { "HTTP ${resp.code}" }
                val body = resp.body?.string().orEmpty()
                val cat = json.decodeFromString<Catalog>(body)
                cached = cat
                cat
            }
        }
    }

    fun channels(): List<Channel> = cached?.channels ?: emptyList()
    fun channelById(id: String): Channel? = cached?.channels?.firstOrNull { it.id == id }
}
