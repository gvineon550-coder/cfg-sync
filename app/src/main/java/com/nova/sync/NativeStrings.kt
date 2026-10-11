package com.nova.sync

object NativeStrings {
    private val loaded: Boolean = try {
        System.loadLibrary("sigcheck"); true
    } catch (_: Throwable) { false }

    private external fun nativeUrl(idx: Int): String?

    val pagesBase: String
        get() = if (loaded) (nativeUrl(0) ?: "") else ""
    val playOptionsTemplate: String
        get() = if (loaded) (nativeUrl(1) ?: "") else ""
}
