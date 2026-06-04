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
import java.io.BufferedInputStream
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL

class MainActivity : FlutterActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val handledDownloadIds = mutableSetOf<Long>()
    private var updateChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        updateChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.navalgo/app_update"
        )
        updateChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "downloadApk" -> {
                    val url = call.argument<String>("url")
                    val fileName = call.argument<String>("fileName") ?: "navalgo-android.apk"
                    val title = call.argument<String>("title") ?: "NavalGO"

                    if (url.isNullOrBlank()) {
                        sendDownloadStatus(
                            "failed",
                            "La URL de descarga de la actualizacion no es valida"
                        )
                        result.error("invalid_url", "La URL de descarga no es valida", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val safeFileName = fileName
                            .replace(Regex("[^A-Za-z0-9._-]"), "_")
                            .ifBlank { "navalgo-android.apk" }
                        val downloadsDir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
                        if (downloadsDir == null) {
                            sendDownloadStatus(
                                "failed",
                                "No se pudo acceder a la carpeta de descargas"
                            )
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

                        sendDownloadStatus("queued", "Preparando descarga de NavalGO")

                        downloadApkDirectly(url, apkFile, title)
                        Toast.makeText(
                            this,
                            "Descargando actualizacion de NavalGO",
                            Toast.LENGTH_LONG
                        ).show()
                        result.success(mapOf("started" to true))
                    } catch (error: Exception) {
                        sendDownloadStatus(
                            "failed",
                            error.message ?: "No se pudo iniciar la descarga"
                        )
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

    private fun downloadApkDirectly(
        sourceUrl: String,
        apkFile: File,
        title: String
    ) {
        Thread {
            var connection: HttpURLConnection? = null
            try {
                sendDownloadStatus("downloading", "Conectando con la descarga de NavalGO")
                connection = (URL(sourceUrl).openConnection() as HttpURLConnection).apply {
                    connectTimeout = 15000
                    readTimeout = 30000
                    instanceFollowRedirects = true
                    requestMethod = "GET"
                    setRequestProperty("User-Agent", "NavalGO Android updater")
                    connect()
                }

                val statusCode = connection.responseCode
                if (statusCode !in 200..299) {
                    throw IllegalStateException("Servidor devolvio HTTP $statusCode")
                }

                val totalBytes = connection.contentLengthLong
                var downloadedBytes = 0L
                var lastProgressSentAt = 0L

                BufferedInputStream(connection.inputStream).use { input ->
                    FileOutputStream(apkFile).use { output ->
                        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                        while (true) {
                            val read = input.read(buffer)
                            if (read == -1) {
                                break
                            }
                            output.write(buffer, 0, read)
                            downloadedBytes += read.toLong()

                            val now = System.currentTimeMillis()
                            if (now - lastProgressSentAt > 500L) {
                                lastProgressSentAt = now
                                val progress = if (totalBytes > 0L) {
                                    downloadedBytes.toDouble() / totalBytes.toDouble()
                                } else {
                                    null
                                }
                                sendDownloadStatus(
                                    "downloading",
                                    "Descargando $title",
                                    progress
                                )
                            }
                        }
                        output.flush()
                    }
                }

                if (!apkFile.exists() || apkFile.length() <= 0L) {
                    throw IllegalStateException("La APK descargada esta vacia")
                }

                sendDownloadStatus("success", "APK descargada. Abriendo instalador")
                mainHandler.post {
                    openApkInstaller(this, apkFile, sourceUrl)
                }
            } catch (error: Exception) {
                Log.e("NavalGOUpdate", "Descarga directa APK fallida", error)
                if (apkFile.exists()) {
                    apkFile.delete()
                }
                sendDownloadStatus(
                    "failed",
                    error.message ?: "No se pudo descargar la actualizacion"
                )
                mainHandler.post {
                    openApkInBrowser(sourceUrl)
                }
            } finally {
                connection?.disconnect()
            }
        }.start()
    }

    private fun sendDownloadStatus(
        status: String,
        message: String,
        progress: Double? = null
    ) {
        mainHandler.post {
            val payload = mutableMapOf<String, Any>(
                "status" to status,
                "message" to message
            )
            if (progress != null) {
                payload["progress"] = progress
            }
            updateChannel?.invokeMethod("downloadStatus", payload)
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
                if (status == DownloadManager.STATUS_RUNNING ||
                    status == DownloadManager.STATUS_PENDING ||
                    status == DownloadManager.STATUS_PAUSED
                ) {
                    val downloaded = cursor.getLong(
                        cursor.getColumnIndexOrThrow(
                            DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR
                        )
                    )
                    val total = cursor.getLong(
                        cursor.getColumnIndexOrThrow(
                            DownloadManager.COLUMN_TOTAL_SIZE_BYTES
                        )
                    )
                    val progress = if (total > 0L) {
                        downloaded.toDouble() / total.toDouble()
                    } else {
                        null
                    }
                    val message = when (status) {
                        DownloadManager.STATUS_PENDING -> "Esperando para descargar NavalGO"
                        DownloadManager.STATUS_PAUSED -> "Descarga pausada por Android"
                        else -> "Descargando actualizacion de NavalGO"
                    }
                    sendDownloadStatus("downloading", message, progress)
                }
                return false
            }

            if (!handledDownloadIds.add(downloadId)) {
                return true
            }

            if (status == DownloadManager.STATUS_SUCCESSFUL && apkFile.exists()) {
                Log.i("NavalGOUpdate", "APK descargado: ${apkFile.absolutePath}")
                sendDownloadStatus("success", "APK descargada. Abriendo instalador")
                openApkInstaller(this, apkFile, sourceUrl)
            } else {
                val reason = cursor.getInt(
                    cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON)
                )
                Log.w("NavalGOUpdate", "Descarga APK fallida. reason=$reason")
                sendDownloadStatus(
                    "failed",
                    "La descarga de NavalGO fallo. Codigo Android: $reason"
                )
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
                sendDownloadStatus(
                    "permission_required",
                    "Permite instalar apps desconocidas y pulsa descargar de nuevo"
                )
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
            sendDownloadStatus("installer_opened", "Instalador de NavalGO abierto")
            context.startActivity(installIntent)
        } catch (error: Exception) {
            Log.e("NavalGOUpdate", "No se pudo abrir instalador", error)
            sendDownloadStatus(
                "failed",
                error.message ?: "No se pudo abrir el instalador de NavalGO"
            )
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
            sendDownloadStatus("browser_opened", "Abriendo descarga en el navegador")
            startActivity(browserIntent)
        } catch (error: Exception) {
            Log.e("NavalGOUpdate", "No se pudo abrir URL APK", error)
            sendDownloadStatus(
                "failed",
                error.message ?: "No se pudo abrir la descarga en el navegador"
            )
        }
    }
}
