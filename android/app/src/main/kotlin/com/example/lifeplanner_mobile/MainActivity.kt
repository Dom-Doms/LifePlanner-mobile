package com.example.lifeplanner_mobile

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val notificationChannelName = "lifeplanner_mobile/local_notifications"
    private val storageChannelName = "lifeplanner_mobile/session_storage"
    private val notificationChannelId = "lifeplanner_workout"
    private val permissionRequestCode = 4907
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notificationChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermission" -> requestNotificationPermission(result)
                    "areNotificationsEnabled" -> result.success(areNotificationsEnabled())
                    "show" -> {
                        val id = call.argument<Int>("id") ?: 1
                        val title = call.argument<String>("title") ?: "LifePlanner"
                        val body = call.argument<String>("body") ?: ""
                        val vibrate = call.argument<Boolean>("vibrate") ?: false
                        showNotification(id, title, body, vibrate)
                        result.success(null)
                    }
                    "vibrate" -> {
                        vibrate()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, storageChannelName)
            .setMethodCallHandler { call, result ->
                val preferences = getSharedPreferences("lifeplanner_session", Context.MODE_PRIVATE)
                when (call.method) {
                    "read" -> result.success(preferences.getString("session", null))
                    "write" -> {
                        preferences.edit().putString("session", call.argument<String>("value")).commit()
                        result.success(null)
                    }
                    "clear" -> {
                        preferences.edit().remove("session").commit()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU || areNotificationsEnabled()) {
            result.success(true)
            return
        }
        pendingPermissionResult = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), permissionRequestCode)
    }

    private fun areNotificationsEnabled(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == permissionRequestCode) {
            pendingPermissionResult?.success(
                grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            )
            pendingPermissionResult = null
        }
    }

    private fun showNotification(id: Int, title: String, body: String, vibrate: Boolean) {
        if (!areNotificationsEnabled()) {
            if (vibrate) vibrate()
            return
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                notificationChannelId,
                "LifePlanner workout",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 180, 90, 180)
            }
            manager.createNotificationChannel(channel)
        }

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(this, notificationChannelId)
        } else {
            @Suppress("DEPRECATION")
            android.app.Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setVibrate(longArrayOf(0, 180, 90, 180))
            .build()
        manager.notify(id, notification)
        if (vibrate) vibrate()
    }

    private fun vibrate() {
        val pattern = longArrayOf(0, 180, 90, 180)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            manager.defaultVibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
        } else {
            @Suppress("DEPRECATION")
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(pattern, -1)
            }
        }
    }
}
