package com.example.navalgo

import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.widget.Toast
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val handledDownloadIds = mutableSetOf<Long>()

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
                        val safeFileName = fileName
                            .replace(Regex("[^A-Za-z0-9._-]"), "_")
                            .ifBlank { "navalgo-android.apk" }
                        val downloadsDir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
                        if (downloadsDir == null) {
                            result.error(
                                "download_failed",
                                "No se pudo acceder a la carpeta de descargas",
                                null
                            )
                            return@setMethodCallHandler
                        }

                        val apkFile = File(downloadsDir, safeFileName)
                        if (apkFile.exists()) {
                            apkFile.delete()
                        }

                        val request = DownloadManager.Request(Uri.parse(url))
                            .setTitle(title)
                            .setDescription("Descargando actualizacion de NavalGO")
                            .setMimeType("application/vnd.android.package-archive")
                            .setNotificationVisibility(
                                DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED
                            )
                            .setAllowedOverMetered(true)
                            .setAllowedOverRoaming(true)
                            .setDestinationUri(Uri.fromFile(apkFile))

                        val downloadManager = getSystemService(
                            Context.DOWNLOAD_SERVICE
                        ) as DownloadManager
                        val downloadId = downloadManager.enqueue(request)
                        registerApkDownloadReceiver(downloadManager, downloadId, apkFile, url)
                        watchApkDownload(downloadManager, downloadId, apkFile, url)
                        Toast.makeText(
                            this,
                            "Descargando actualizacion de NavalGO",
                            Toast.LENGTH_LONG
                        ).show()
                        result.success(mapOf("downloadId" to downloadId))
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

    private fun registerApkDownloadReceiver(
        downloadManager: DownloadManager,
        downloadId: Long,
        apkFile: File,
        sourceUrl: String
    ) {
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val completedId = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1)
                if (completedId != downloadId) {
                    return
                }

                try {
                    context.unregisterReceiver(this)
                } catch (_: Exception) {
                }

                handleApkDownloadState(downloadManager, downloadId, apkFile, sourceUrl)
            }
        }

        val filter = IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(receiver, filter)
        }
    }

    private fun watchApkDownload(
        downloadManager: DownloadManager,
        downloadId: Long,
        apkFile: File,
        sourceUrl: String,
        attempt: Int = 0
    ) {
        mainHandler.postDelayed({
            if (handledDownloadIds.contains(downloadId)) {
                return@postDelayed
            }
            val finished = handleApkDownloadState(downloadManager, downloadId, apkFile, sourceUrl)
            if (!finished && attempt < 900) {
                watchApkDownload(downloadManager, downloadId, apkFile, sourceUrl, attempt + 1)
            }
        }, 1000L)
    }

    private fun handleApkDownloadState(
        downloadManager: DownloadManager,
        downloadId: Long,
        apkFile: File,
        sourceUrl: String
    ): Boolean {
        val query = DownloadManager.Query().setFilterById(downloadId)
        downloadManager.query(query).use { cursor ->
            if (cursor == null || !cursor.moveToFirst()) {
                return false
            }

            val status = cursor.getInt(
                cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS)
            )
            if (status != DownloadManager.STATUS_SUCCESSFUL &&
                status != DownloadManager.STATUS_FAILED
            ) {
                return false
            }

            if (!handledDownloadIds.add(downloadId)) {
                return true
            }

            if (status == DownloadManager.STATUS_SUCCESSFUL && apkFile.exists()) {
                Log.i("NavalGOUpdate", "APK descargado: ${apkFile.absolutePath}")
                openApkInstaller(this, apkFile, sourceUrl)
            } else {
                val reason = cursor.getInt(
                    cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON)
                )
                Log.w("NavalGOUpdate", "Descarga APK fallida. reason=$reason")
                Toast.makeText(
                    this,
                    "La descarga de NavalGO fallo ($reason)",
                    Toast.LENGTH_LONG
                ).show()
                openApkInBrowser(sourceUrl)
            }
            return true
        }
    }

    private fun openApkInstaller(context: Context, apkFile: File, sourceUrl: String) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                !context.packageManager.canRequestPackageInstalls()
            ) {
                Toast.makeText(
                    context,
                    "Permite instalar actualizaciones de NavalGO y pulsa descargar de nuevo",
                    Toast.LENGTH_LONG
                ).show()
                val settingsIntent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                    data = Uri.parse("package:${context.packageName}")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(settingsIntent)
                return
            }

            val apkUri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                apkFile
            )
            val installIntent = Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
                data = apkUri
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                putExtra(Intent.EXTRA_NOT_UNKNOWN_SOURCE, false)
                putExtra(Intent.EXTRA_RETURN_RESULT, true)
            }
            Log.i("NavalGOUpdate", "Abriendo instalador APK")
            context.startActivity(installIntent)
        } catch (error: Exception) {
            Log.e("NavalGOUpdate", "No se pudo abrir instalador", error)
            Toast.makeText(
                context,
                error.message ?: "No se pudo abrir el instalador de NavalGO",
                Toast.LENGTH_LONG
            ).show()
            openApkInBrowser(sourceUrl)
        }
    }

    private fun openApkInBrowser(sourceUrl: String) {
        try {
            val browserIntent = Intent(Intent.ACTION_VIEW, Uri.parse(sourceUrl)).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(browserIntent)
        } catch (error: Exception) {
            Log.e("NavalGOUpdate", "No se pudo abrir URL APK", error)
        }
    }
}
