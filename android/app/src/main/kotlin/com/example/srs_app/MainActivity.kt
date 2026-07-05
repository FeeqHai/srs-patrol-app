package com.example.srs_app

import android.content.ContentValues
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val downloadsChannel = "srs_app/downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            downloadsChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "savePdfToDownloads" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val filename = call.argument<String>("filename")
                    if (bytes == null || bytes.isEmpty()) {
                        result.error("INVALID_BYTES", "PDF data is empty.", null)
                        return@setMethodCallHandler
                    }
                    if (filename.isNullOrBlank()) {
                        result.error("INVALID_FILENAME", "File name is empty.", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val uri = savePdfToDownloads(bytes, filename)
                        result.success(uri.toString())
                    } catch (error: Exception) {
                        result.error("SAVE_FAILED", error.message, null)
                    }
                }
                "openDownloadedFile" -> {
                    val target = call.argument<String>("target")
                        ?: call.argument<String>("path")
                    if (target.isNullOrBlank()) {
                        result.error("INVALID_TARGET", "File target is empty.", null)
                        return@setMethodCallHandler
                    }

                    try {
                        openDownloadedFile(target)
                        result.success(true)
                    } catch (error: Exception) {
                        result.error("OPEN_FAILED", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun savePdfToDownloads(bytes: ByteArray, filename: String): Uri {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
                put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val resolver = applicationContext.contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Unable to create file in Downloads.")

            try {
                resolver.openOutputStream(uri)?.use { stream ->
                    stream.write(bytes)
                } ?: throw IllegalStateException("Unable to open Downloads output stream.")

                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                uri
            } catch (error: Exception) {
                resolver.delete(uri, null, null)
                throw error
            }
        } else {
            val downloadsDir = Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_DOWNLOADS
            )
            if (!downloadsDir.exists() && !downloadsDir.mkdirs()) {
                throw IllegalStateException("Unable to access Downloads folder.")
            }
            val file = File(downloadsDir, filename)
            file.writeBytes(bytes)
            FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.fileprovider",
                file
            )
        }
    }

    private fun openDownloadedFile(target: String) {
        val uri = if (target.startsWith("content://")) {
            Uri.parse(target)
        } else {
            val file = File(target)
            if (!file.exists()) {
                throw IllegalArgumentException("File not found: $target")
            }
            FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.fileprovider",
                file
            )
        }
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/pdf")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        try {
            startActivity(Intent.createChooser(intent, "Open PDF"))
        } catch (error: ActivityNotFoundException) {
            throw ActivityNotFoundException("No app found to open PDF files.")
        }
    }
}
