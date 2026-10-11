package com.nova.sync.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class Channel(
    val id: String,
    val title: String = "",
    val description: String = "",
    val category: String? = null,
    val avatar: String = "",
    @SerialName("stream_url") val streamUrl: String? = null,
    val blocked: Boolean = false,
    @SerialName("blocked_reason") val blockedReason: String = "",
    val unavailable: Boolean = false,
)

@Serializable
data class Catalog(
    val updated: String = "",
    val total: Int = 0,
    @SerialName("with_url") val withUrl: Int = 0,
    @SerialName("no_url") val noUrl: Int = 0,
    val channels: List<Channel> = emptyList(),
)

@Serializable
data class TrustedDevices(
    val devices: List<String> = emptyList(),
)
