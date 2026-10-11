package com.nova.sync.data

import com.nova.sync.NativeStrings
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

object TrustedDeviceStore {
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(20, TimeUnit.SECONDS)
        .build()
    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    @Volatile private var cache: Set<String>? = null

    suspend fun refresh() = withContext(Dispatchers.IO) {
        runCatching {
            val url = NativeStrings.pagesBase + "trusted_devices.json"
            val req = Request.Builder().url(url).build()
            client.newCall(req).execute().use { resp ->
                require(resp.isSuccessful) { "HTTP ${resp.code}" }
                val body = resp.body?.string().orEmpty()
                val td = json.decodeFromString<TrustedDevices>(body)
                cache = td.devices.toSet()
            }
        }
    }

    fun isTrusted(id: String): Boolean = cache?.contains(id) == true
    fun cached(): Set<String> = cache ?: emptySet()
}
