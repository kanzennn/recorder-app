package com.faize.recorder_app

import android.content.ContentValues
import android.content.Context
import android.os.Environment
import android.provider.MediaStore
import io.flutter.plugin.common.MethodChannel

// Nulis file unduhan (WAV take dari ESP32) ke folder Download publik lewat
// MediaStore, biar kelihatan di file manager HP -- beda dari folder internal
// app (path_provider's getApplicationDocumentsDirectory) yang nggak kelihatan
// tanpa root. minSdk project ini sudah 29 (Android 10+), jadi MediaStore.Downloads
// selalu tersedia, nggak perlu fallback legacy / permission WRITE_EXTERNAL_STORAGE.
class DownloadsChannel(private val context: Context) {
    fun saveToDownloads(fileName: String, bytes: ByteArray, result: MethodChannel.Result) {
        try {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, "audio/wav")
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            }
            val resolver = context.contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Gagal membuat entri MediaStore")
            resolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw IllegalStateException("Gagal membuka output stream")
            result.success("Download/$fileName")
        } catch (e: Exception) {
            result.error("SAVE_FAILED", e.message, null)
        }
    }
}
