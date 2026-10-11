package com.nova.sync

object NativeStrings {
    private val loaded: Boolean = try {
        System.loadLibrary("sigcheck")
        true
    } catch (_: Throwable) {
        false
    }

    private external fun nativeUrl(idx: Int): String?
    private external fun nativeUa(idx: Int): String?

    private const val FALLBACK_DESKTOP =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
    private const val FALLBACK_MOBILE =
        "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36"

    val pagesBase: String
        get() = if (loaded) (nativeUrl(0) ?: "") else ""
    val playOptionsTemplate: String
        get() = if (loaded) (nativeUrl(1) ?: "") else ""
    val uaDesktop: String
        get() = if (loaded) (nativeUa(0) ?: FALLBACK_DESKTOP) else FALLBACK_DESKTOP
    val uaMobile: String
        get() = if (loaded) (nativeUa(1) ?: FALLBACK_MOBILE) else FALLBACK_MOBILE
}
