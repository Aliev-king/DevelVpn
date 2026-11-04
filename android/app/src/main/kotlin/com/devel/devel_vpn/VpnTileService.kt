package com.devel.devel_vpn

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import dev.amirzr.flutter_v2ray_client.v2ray.V2rayController
import dev.amirzr.flutter_v2ray_client.v2ray.utils.AppConfigs
import java.util.ArrayList

/**
 * Quick-settings tile for DevelVpn.
 * Toggles VPN connection directly in the background WITHOUT opening the app.
 */
class VpnTileService : TileService() {

    private val v2rayReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            updateTileState()
        }
    }

    override fun onStartListening() {
        super.onStartListening()
        updateTileState()
        try {
            val filter = IntentFilter("$packageName.V2RAY_CONNECTION_INFO")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(v2rayReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(v2rayReceiver, filter)
            }
        } catch (_: Exception) {}
    }

    override fun onStopListening() {
        super.onStopListening()
        try {
            unregisterReceiver(v2rayReceiver)
        } catch (_: Exception) {}
    }

    private fun updateTileState() {
        val tile = qsTile ?: return
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val isCoreRunning = V2rayController.getConnectionState() == AppConfigs.V2RAY_STATES.V2RAY_CONNECTED
        val isVpnActive = isCoreRunning || prefs.getBoolean("flutter.vpn_active", false)

        tile.state = if (isVpnActive) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.label = "DevelVpn"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = if (isVpnActive) "Connected" else "Disconnected"
        }
        tile.updateTile()
    }

    override fun onClick() {
        super.onClick()
        val tile = qsTile ?: return
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val isCoreRunning = V2rayController.getConnectionState() == AppConfigs.V2RAY_STATES.V2RAY_CONNECTED
        val isVpnActive = isCoreRunning || prefs.getBoolean("flutter.vpn_active", false)

        if (isVpnActive) {
            // DIRECTLY STOP VPN IN BACKGROUND - NO APP OPENING
            V2rayController.StopV2ray(applicationContext)
            prefs.edit().putBoolean("flutter.vpn_active", false).apply()
            tile.state = Tile.STATE_INACTIVE
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                tile.subtitle = "Disconnected"
            }
            tile.updateTile()
        } else {
            // DIRECTLY START VPN IN BACKGROUND - NO APP OPENING
            val config = prefs.getString("flutter.last_v2ray_config", null)
            val remark = prefs.getString("flutter.last_v2ray_remark", "DevelVpn") ?: "DevelVpn"
            if (!config.isNullOrEmpty()) {
                val blockedApps = ArrayList<String>().apply { add("com.devel.devel_vpn") }
                V2rayController.StartV2ray(applicationContext, remark, config, blockedApps, null)
                prefs.edit().putBoolean("flutter.vpn_active", true).apply()
                tile.state = Tile.STATE_ACTIVE
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    tile.subtitle = "Connecting..."
                }
                tile.updateTile()
            } else {
                // Only if no config was ever loaded, launch app
                val intent = Intent(this, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    val pendingIntent = android.app.PendingIntent.getActivity(
                        this, 101, intent,
                        android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                    )
                    startActivityAndCollapse(pendingIntent)
                } else {
                    @Suppress("DEPRECATION")
                    startActivityAndCollapse(intent)
                }
            }
        }
    }
}
