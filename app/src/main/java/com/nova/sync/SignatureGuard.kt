package com.nova.sync

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import com.nova.sync.data.TrustedDeviceStore
import java.security.MessageDigest

sealed class TrustState {
    object Trusted : TrustState()
    data class Untrusted(val androidId: String) : TrustState()
    data class Unreliable(val reason: String) : TrustState()
}

object SignatureGuard {
    private const val EXPECTED_SHA256 =
        "0f407f281165dd946ccf13aed1b171e02fdadd538894af7ce12826e7bf300b5a"

    private var appCtx: Context? = null
    private val loaded: Boolean = try {
        System.loadLibrary("sigcheck"); true
    } catch (_: Throwable) { false }

    fun init(ctx: Context) { appCtx = ctx.applicationContext }

    suspend fun resolve(): TrustState {
        val ctx = appCtx ?: return TrustState.Unreliable("no_context")

        val actual = signatureSha256(ctx) ?: return TrustState.Unreliable("no_signature")
        if (!actual.equals(EXPECTED_SHA256, ignoreCase = true)) {
            return TrustState.Unreliable("bad_signature")
        }

        if (loaded && nativeIsTampered()) {
            return TrustState.Unreliable("tampered")
        }

        val androidId = Settings.Secure.getString(
            ctx.contentResolver, Settings.Secure.ANDROID_ID
        ) ?: return TrustState.Unreliable("no_android_id")

        TrustedDeviceStore.refresh()
        return if (TrustedDeviceStore.isTrusted(androidId))
            TrustState.Trusted
        else
            TrustState.Untrusted(androidId)
    }

    private fun signatureSha256(ctx: Context): String? = try {
        val pm = ctx.packageManager
        val pkg = if (Build.VERSION.SDK_INT >= 33)
            pm.getPackageInfo(
                ctx.packageName,
                PackageManager.PackageInfoFlags.of(
                    PackageManager.GET_SIGNING_CERTIFICATES.toLong()
                )
            )
        else
            @Suppress("DEPRECATION")
            pm.getPackageInfo(ctx.packageName, PackageManager.GET_SIGNING_CERTIFICATES)

        val signatures = if (Build.VERSION.SDK_INT >= 28)
            pkg.signingInfo?.apkContentsSigners
        else
            @Suppress("DEPRECATION") pkg.signatures

        val sig = signatures?.firstOrNull() ?: return null
        MessageDigest.getInstance("SHA-256")
            .digest(sig.toByteArray())
            .joinToString("") { "%02x".format(it) }
    } catch (_: Throwable) { null }

    private external fun nativeIsTampered(): Boolean
}
