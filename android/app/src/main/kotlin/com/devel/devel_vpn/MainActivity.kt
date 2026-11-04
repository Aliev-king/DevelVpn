package com.devel.devel_vpn

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "devel_vpn/links"
    private val otaChannelName = "devel_vpn/ota"
    private val appsChannelName = "devel_vpn/apps"
    private val widgetChannelName = "devel_vpn/widget"
    private val notifChannelName = "devel_vpn/notification"
    private var pendingLink: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            if (call.method == "takePendingLink") {
                val link = pendingLink
                pendingLink = null
                result.success(link)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, appsChannelName).setMethodCallHandler { call, result ->
            if (call.method == "getInstalledApps") {
                val includeSystem = call.argument<Boolean>("includeSystem") ?: false
                val apps = ArrayList<Map<String, String>>()
                for (info in packageManager.getInstalledPackages(0)) {
                    val flags = info.applicationInfo?.flags ?: 0
                    val isSystem = (flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0
                    if (isSystem && !includeSystem) continue
                    if (info.packageName == packageName) continue
                    val label = try {
                        info.applicationInfo?.loadLabel(packageManager)?.toString() ?: continue
                    } catch (_: Exception) {
                        continue
                    }
                    apps.add(mapOf("package" to info.packageName, "label" to label))
                }
                apps.sortBy { it["label"]?.lowercase() ?: "" }
                result.success(mapOf("apps" to apps, "self" to packageName))
            } else if (call.method == "getForegroundApp") {
                var pkg: String? = null
                try {
                    val usm = getSystemService(Context.USAGE_STATS_SERVICE) as android.app.usage.UsageStatsManager
                    val now = System.currentTimeMillis()
                    val events = usm.queryEvents(now - 60_000L, now)
                    var lastPkg: String? = null
                    var lastTime = 0L
                    val ev = android.app.usage.UsageEvents.Event()
                    while (events.hasNextEvent()) {
                        events.getNextEvent(ev)
                        if (ev.eventType == android.app.usage.UsageEvents.Event.ACTIVITY_RESUMED) {
                            if (ev.timeStamp >= lastTime) { lastTime = ev.timeStamp; lastPkg = ev.packageName }
                        }
                    }
                    pkg = lastPkg
                } catch (_: Exception) {}
                result.success(pkg)
            } else if (call.method == "hasUsageAccess") {
                // PACKAGE_USAGE_STATS is an AppOps permission — checkSelfPermission
                // always returns DENIED for it, even when the user granted access.
                val appOps = getSystemService(Context.APP_OPS_SERVICE) as android.app.AppOpsManager
                val mode = appOps.checkOpNoThrow(
                    "android:get_usage_stats",
                    android.os.Process.myUid(),
                    packageName,
                )
                result.success(mode == android.app.AppOpsManager.MODE_ALLOWED)
            } else if (call.method == "openUsageAccessSettings") {
                try {
                    startActivity(Intent(android.provider.Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(true)
                } catch (e: Exception) {
                    result.error("ERROR", e.message, null)
                }
            }
            else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, widgetChannelName).setMethodCallHandler { call, result ->
            if (call.method == "update") {
                try {
                    DevelVpnWidgetProvider.pushAll(this)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, otaChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCacheDir" -> {
                    result.success(cacheDir.absolutePath)
                }
                "canInstallPackages" -> {
                    val canInstall = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        packageManager.canRequestPackageInstalls()
                    } else {
                        true
                    }
                    result.success(canInstall)
                }
                "openInstallSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val intent = Intent(android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = android.net.Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("INVALID_ARGS", "path is required", null)
                        return@setMethodCallHandler
                    }
                    val file = java.io.File(path)
                    if (!file.exists()) {
                        result.error("NOT_FOUND", "File not found: $path", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val uri = androidx.core.content.FileProvider.getUriForFile(
                            this,
                            "$packageName.fileprovider",
                            file
                        )
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notifChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateNotification" -> {
                    val title = call.argument<String>("title") ?: "DevelVpn"
                    val content = call.argument<String>("content")
                    val ping = call.argument<Int>("ping")
                    updateVpnNotification(title, content, ping)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun updateVpnNotification(title: String, content: String?, ping: Int?) {
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                action = "FROM_DISCONNECT_BTN"
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                android.app.PendingIntent.FLAG_IMMUTABLE or android.app.PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                android.app.PendingIntent.FLAG_UPDATE_CURRENT
            }
            val contentPendingIntent = android.app.PendingIntent.getActivity(this, 0, launchIntent, flags)

            val displayTitle = if (ping != null && ping > 0) {
                "$title · $ping ms"
            } else {
                title
            }

            val iconId = resources.getIdentifier("ic_notification", "drawable", packageName).let {
                if (it != 0) it else android.R.drawable.ic_dialog_info
            }

            val builder = androidx.core.app.NotificationCompat.Builder(this, "A_FLUTTER_V2RAY_SERVICE_CH_ID")
                .setSmallIcon(iconId)
                .setContentTitle(displayTitle)
                // Keep the DISCONNECT action: notify() replaces the foreground
                // notification and would otherwise drop the plugin's button.
                .addAction(0, "DISCONNECT", contentPendingIntent)
                .setPriority(androidx.core.app.NotificationCompat.PRIORITY_LOW)
                .setShowWhen(false)
                .setOnlyAlertOnce(true)
                .setContentIntent(contentPendingIntent)
                .setSilent(true)
                .setOngoing(true)

            if (!content.isNullOrEmpty()) {
                builder.setContentText(content)
            }

            notificationManager.notify(1, builder.build())
        } catch (_: Exception) {}
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestNotificationPermission()
        setupSilentNotificationChannel()
        handleIntent(intent)
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 101)
            }
        }
    }

    private fun setupSilentNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            if (notificationManager != null) {
                // Delete old channels that might have had sound/vibration
                try {
                    notificationManager.deleteNotificationChannel("A_FLUTTER_V2RAY_SERVICE_CH_ID")
                    notificationManager.deleteNotificationChannel("V2RAY_SERVICE_CH_ID")
                } catch (_: Exception) {}

                val channel = NotificationChannel(
                    "A_FLUTTER_V2RAY_SERVICE_CH_ID",
                    "DevelVpn Service",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "DevelVpn connection status"
                    setSound(null, null)
                    enableVibration(false)
                    setShowBadge(false)
                }
                notificationManager.createNotificationChannel(channel)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
        setIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val data = intent?.data ?: return
        if (data.scheme == "happ" || data.scheme == "develvpn") {
            if (data.host == "add") {
                val inner = intent.dataString ?: return
                pendingLink = inner.substringAfter("add/", "")
            }
        }
    }
}
