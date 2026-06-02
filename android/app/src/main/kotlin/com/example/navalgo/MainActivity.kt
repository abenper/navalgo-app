package com.example.navalgo

import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.navalgo/app_update"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "downloadApk" -> {
                    val url = call.argument<String>("url")
                    val fileName = call.argument<String>("fileName") ?: "navalgo-android.apk"
                    val title = call.argument<String>("title") ?: "NavalGO"

                    if (url.isNullOrBlank()) {
                        result.error("invalid_url", "La URL de descarga no es valida", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val request = DownloadManager.Request(Uri.parse(url))
                            .setTitle(title)
                            .setDescription("Descargando actualizacion de NavalGO")
                            .setMimeType("application/vnd.android.package-archive")
                            .setNotificationVisibility(
                                DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED
                            )
                            .setAllowedOverMetered(true)
                            .setAllowedOverRoaming(true)
                            .setDestinationInExternalPublicDir(
                                Environment.DIRECTORY_DOWNLOADS,
                                fileName
                            )

                        val downloadManager = getSystemService(
                            Context.DOWNLOAD_SERVICE
                        ) as DownloadManager
                        val downloadId = downloadManager.enqueue(request)
                        result.success(downloadId)
                    } catch (error: Exception) {
                        result.error(
                            "download_failed",
                            error.message ?: "No se pudo iniciar la descarga",
                            null
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
