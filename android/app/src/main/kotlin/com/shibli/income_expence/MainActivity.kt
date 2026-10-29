package com.shibli.income_expence

import android.Manifest
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "expolio/notification_capture"
    private val smsPermissionRequestCode = 7314
    private val notificationPermissionRequestCode = 7315
    private var captureMethodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        captureMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        captureMethodChannel?.setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasNotificationAccess" -> result.success(hasNotificationAccess())
                    "openNotificationSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                            result.success(true)
                        } catch (exception: Exception) {
                            result.error("SETTINGS_ERROR", exception.message, null)
                        }
                    }
                    "getCapturedNotifications" -> {
                        result.success(NotificationCaptureService.getCapturedNotifications(this))
                    }
                    "clearCapturedNotifications" -> {
                        NotificationCaptureService.clearCapturedNotifications(this)
                        result.success(true)
                    }
                    "hasOverlayPermission" -> result.success(android.provider.Settings.canDrawOverlays(this))
                    "openOverlaySettings" -> {
                        try {
                            val overlayIntent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                android.net.Uri.parse("package:$packageName")
                            )
                            startActivity(overlayIntent)
                            result.success(true)
                        } catch (exception: Exception) {
                            result.error("OVERLAY_SETTINGS_ERROR", exception.message, null)
                        }
                    }
                    "hasSmsPermission" -> result.success(hasSmsPermission())
                    "hasPostNotificationsPermission" -> result.success(hasPostNotificationsPermission())
                    "requestPostNotificationsPermission" -> {
                        try {
                            if (hasPostNotificationsPermission()) {
                                result.success(true)
                            } else if (Build.VERSION.SDK_INT >= 33) {
                                requestPermissions(
                                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                    notificationPermissionRequestCode
                                )
                                result.success(true)
                            } else {
                                result.success(true)
                            }
                        } catch (exception: Exception) {
                            result.error("NOTIFICATION_PERMISSION_ERROR", exception.message, null)
                        }
                    }
                    "consumeOpenAutoCaptureIntent" -> {
                        val shouldOpen = intent?.getBooleanExtra(
                            SmsTransactionReceiver.EXTRA_OPEN_AUTO_CAPTURE, false
                        ) == true
                        if (shouldOpen) {
                            intent?.removeExtra(SmsTransactionReceiver.EXTRA_OPEN_AUTO_CAPTURE)
                            intent?.removeExtra(SmsTransactionReceiver.EXTRA_CAPTURE_EVENT_ID)
                        }
                        result.success(shouldOpen)
                    }
                    "requestSmsPermission" -> {
                        try {
                            if (hasSmsPermission()) {
                                result.success(true)
                            } else {
                                requestPermissions(
                                    arrayOf(Manifest.permission.RECEIVE_SMS),
                                    smsPermissionRequestCode
                                )
                                // This only means the Android permission dialog was launched.
                                // The Flutter page re-checks the actual permission on resume.
                                result.success(true)
                            }
                        } catch (exception: Exception) {
                            result.error("SMS_PERMISSION_ERROR", exception.message, null)
                        }
                    }
                    "getCapturedSmsEvents" -> {
                        result.success(SmsTransactionReceiver.getCapturedEvents(this))
                    }
                    "clearCapturedSmsEvents" -> {
                        SmsTransactionReceiver.clearCapturedEvents(this)
                        result.success(true)
                    }
                    "removeCapturedSmsEvent" -> {
                        val eventId = call.argument<String>("id")
                        if (eventId.isNullOrBlank()) {
                            result.error("INVALID_EVENT_ID", "A captured SMS event ID is required.", null)
                        } else {
                            SmsTransactionReceiver.removeCapturedEvent(this, eventId)
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra(SmsTransactionReceiver.EXTRA_OPEN_AUTO_CAPTURE, false)) {
            captureMethodChannel?.invokeMethod("openAutoCapture", null)
        }
    }

    private fun hasPostNotificationsPermission(): Boolean {
        if (Build.VERSION.SDK_INT < 33) return true
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED &&
            androidx.core.app.NotificationManagerCompat.from(this).areNotificationsEnabled()
    }

    private fun hasNotificationAccess(): Boolean {
        val enabledListeners = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners"
        ) ?: return false

        val component = ComponentName(this, NotificationCaptureService::class.java)
        return enabledListeners.split(':').any { entry ->
            val enabledComponent = ComponentName.unflattenFromString(entry)
            enabledComponent?.packageName == component.packageName &&
                enabledComponent.className == component.className
        }
    }

    private fun hasSmsPermission(): Boolean =
        ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECEIVE_SMS
        ) == PackageManager.PERMISSION_GRANTED
}
