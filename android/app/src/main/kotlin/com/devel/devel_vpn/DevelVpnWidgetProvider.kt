package com.devel.devel_vpn

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import dev.amirzr.flutter_v2ray_client.v2ray.V2rayController
import dev.amirzr.flutter_v2ray_client.v2ray.utils.AppConfigs

/** Home-screen widget: one-tap VPN toggle + status line. */
class DevelVpnWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) push(context, manager, id)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_TOGGLE -> toggle(context)
            Intent.ACTION_BOOT_COMPLETED -> pushAll(context)
        }
    }

    private fun toggle(context: Context) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val connected = V2rayController.getConnectionState() == AppConfigs.V2RAY_STATES.V2RAY_CONNECTED
        if (connected) {
            V2rayController.StopV2ray(context)
            prefs.edit().putBoolean("flutter.vpn_active", false).apply()
        } else {
            val config = prefs.getString("flutter.last_v2ray_config", null)
            val remark = prefs.getString("flutter.last_v2ray_remark", "DevelVpn") ?: "DevelVpn"
            if (!config.isNullOrEmpty()) {
                V2rayController.StartV2ray(context, remark, config, null, null)
                prefs.edit().putBoolean("flutter.vpn_active", true).apply()
            }
        }
        pushAll(context)
    }

    companion object {
        const val ACTION_TOGGLE = "com.devel.devel_vpn.WIDGET_TOGGLE"

        fun pushAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, DevelVpnWidgetProvider::class.java))
            for (id in ids) push(context, manager, id)
        }

        private fun push(context: Context, manager: AppWidgetManager, id: Int) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val connected = V2rayController.getConnectionState() == AppConfigs.V2RAY_STATES.V2RAY_CONNECTED ||
                    prefs.getBoolean("flutter.vpn_active", false)

            val toggleIntent = Intent(context, DevelVpnWidgetProvider::class.java).apply {
                action = ACTION_TOGGLE
            }
            val togglePending = PendingIntent.getBroadcast(
                context, 0, toggleIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            val openIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val openPending = PendingIntent.getActivity(
                context, 1, openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            val views = RemoteViews(context.packageName, R.layout.vpn_widget).apply {
                setTextViewText(R.id.widget_status, if (connected) "CONNECTED" else "DISCONNECTED")
                setTextColor(R.id.widget_status, if (connected) 0xFF7BAF8B.toInt() else 0xFF9E9EA4.toInt())
                setOnClickPendingIntent(R.id.widget_btn, togglePending)
                setOnClickPendingIntent(R.id.widget_root, openPending)
            }
            manager.updateAppWidget(id, views)
        }
    }
}

/** Handles the widget's toggle tap entirely in the background. */
class WidgetToggleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == DevelVpnWidgetProvider.ACTION_TOGGLE) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val connected = V2rayController.getConnectionState() == AppConfigs.V2RAY_STATES.V2RAY_CONNECTED
            if (connected) {
                V2rayController.StopV2ray(context)
                prefs.edit().putBoolean("flutter.vpn_active", false).apply()
            } else {
                val config = prefs.getString("flutter.last_v2ray_config", null)
                val remark = prefs.getString("flutter.last_v2ray_remark", "DevelVpn") ?: "DevelVpn"
                if (!config.isNullOrEmpty()) {
                    V2rayController.StartV2ray(context, remark, config, null, null)
                    prefs.edit().putBoolean("flutter.vpn_active", true).apply()
                }
            }
            DevelVpnWidgetProvider.pushAll(context)
        }
    }
}
