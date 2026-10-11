package com.nova.sync.ui

import android.graphics.Bitmap
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.QRCodeWriter

fun generateQrBitmap(text: String, size: Int = 512): ImageBitmap? {
    if (text.isBlank()) return null
    return try {
        val hints = mapOf(EncodeHintType.MARGIN to 1)
        val matrix = QRCodeWriter().encode(text, BarcodeFormat.QR_CODE, size, size, hints)
        val pixels = IntArray(size * size)
        val black = android.graphics.Color.BLACK
        val white = android.graphics.Color.WHITE
        for (y in 0 until size) {
            val offset = y * size
            for (x in 0 until size) {
                pixels[offset + x] = if (matrix.get(x, y)) black else white
            }
        }
        val bmp = Bitmap.createBitmap(pixels, size, size, Bitmap.Config.ARGB_8888)
        bmp.asImageBitmap()
    } catch (_: Throwable) {
        null
    }
}
