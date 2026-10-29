package com.shibli.income_expence

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest
import java.util.Locale
import java.util.UUID
import java.util.regex.Pattern

/**
 * Personal APK proof-of-concept for bank transaction SMS parsing.
 *
 * Privacy by design:
 * - Does not request READ_SMS and cannot browse the user's inbox.
 * - Only reacts to newly received SMS broadcasts.
 * - Never stores or uploads the raw SMS body or full sender address.
 * - Stores a compact local event only when transaction-like wording and an amount match.
 * - Does not write to Firestore or create an expense automatically.
 *
 * RECEIVE_SMS is a hard-restricted Android permission on current Android releases. The OS or
 * installer may refuse to grant it to a sideloaded APK; Google Play use requires policy review.
 */
class SmsTransactionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val receivedIntent = intent ?: return
        if (receivedIntent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        try {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(receivedIntent)
            if (messages.isNullOrEmpty()) return

            val body = messages.joinToString(separator = "") { it.messageBody.orEmpty() }.trim()
            if (body.isBlank() || !looksLikeFinancialTransaction(body)) return

            val amount = extractAmount(body) ?: return
            val direction = detectDirection(body)
            val reference = extractReference(body)
            val timestamp = messages.minOfOrNull { it.timestampMillis } ?: System.currentTimeMillis()
            val fingerprint = sha256(
                listOf(
                    normalize(body),
                    amount.toString(),
                    direction,
                    timestamp.toString()
                ).joinToString("|")
            )

            val event = JSONObject().apply {
                put("id", UUID.randomUUID().toString())
                put("source", "sms")
                put("appName", "Bank SMS")
                put("amount", amount)
                put("direction", direction)
                put("merchant", extractMerchant(body))
                put("reference", reference)
                put("accountHint", extractAccountHint(body))
                put("postedAt", timestamp)
                put("capturedAt", System.currentTimeMillis())
                put("fingerprint", fingerprint)
                put("summary", "A transaction-like bank SMS was matched. Original message not stored.")
            }
            val saved = saveEvent(context.applicationContext, event)
            if (saved) {
                // Prefer the floating popup when overlay permission is enabled. Do not also
                // post a tray notification for the same event, which would duplicate the UI.
                // Keep the notification as a fallback when overlays are not permitted or
                // Android rejects the service start.
                val canShowOverlay = android.provider.Settings.canDrawOverlays(context)
                var overlayStartRequested = false
                if (canShowOverlay) {
                    try {
                        val overlayIntent = Intent(context, FloatingTransactionOverlayService::class.java).apply {
                            putExtra(SmsTransactionReceiver.EXTRA_CAPTURE_EVENT_ID, event.optString("id"))
                        }
                        context.startService(overlayIntent)
                        overlayStartRequested = true
                    } catch (e: Exception) {
                        Log.w(TAG, "Could not start floating transaction popup; falling back to notification", e)
                    }
                }
                if (!overlayStartRequested) {
                    showTransactionNotification(context.applicationContext, event)
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not parse incoming SMS as a transaction", e)
        }
    }

    private fun showTransactionNotification(context: Context, event: JSONObject) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Automatic expense capture",
                android.app.NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alerts when Expolio detects a possible bank transaction"
                lockscreenVisibility = android.app.Notification.VISIBILITY_PRIVATE
            }
            manager.createNotificationChannel(channel)
        }

        // Keep amounts, merchant names and bank details off the lock screen.
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_OPEN_AUTO_CAPTURE, true)
            putExtra(EXTRA_CAPTURE_EVENT_ID, event.optString("id"))
        }
        val pendingIntent = android.app.PendingIntent.getActivity(
            context,
            event.optString("id").hashCode(),
            openIntent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )
        val notification = androidx.core.app.NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Expolio detected a transaction")
            .setContentText("Tap to review and choose a category and wallet.")
            .setStyle(androidx.core.app.NotificationCompat.BigTextStyle().bigText("A bank transaction was detected. Open Expolio to review it and choose a category and wallet."))
            .setPriority(androidx.core.app.NotificationCompat.PRIORITY_HIGH)
            .setCategory(androidx.core.app.NotificationCompat.CATEGORY_STATUS)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        // POST_NOTIFICATIONS must be granted on Android 13+. If not, the local event is still
        // retained and will appear in Auto Expense Capture when the app is opened.
        if (androidx.core.app.NotificationManagerCompat.from(context).areNotificationsEnabled() &&
            (android.os.Build.VERSION.SDK_INT < 33 ||
                androidx.core.content.ContextCompat.checkSelfPermission(
                    context, android.Manifest.permission.POST_NOTIFICATIONS
                ) == android.content.pm.PackageManager.PERMISSION_GRANTED)) {
            androidx.core.app.NotificationManagerCompat.from(context).notify(
                (event.optString("id").hashCode() and 0x7fffffff), notification
            )
        }
    }

    private fun looksLikeFinancialTransaction(body: String): Boolean {
        val text = body.lowercase(Locale.ROOT)
        val strongSignals = listOf(
            "debited", "credited", "withdrawn", "deposited", "upi", "utr", "transaction id",
            "txn id", "account debited", "account credited", "a/c debited", "a/c credited",
            "purchase of", "payment of", "sent to", "received from", "transferred"
        )
        val hasFinancialSignal = strongSignals.any { text.contains(it) }
        val hasAmountMarker = Regex("(?:₹|\\binr\\b|\\brs\\.?\\s*)\\s*[0-9][0-9,]*(?:\\.[0-9]{1,2})?", RegexOption.IGNORE_CASE)
            .containsMatchIn(body)
        return hasFinancialSignal && hasAmountMarker
    }

    private fun extractAmount(body: String): Double? {
        // Prefer the amount immediately attached to the transaction direction. Bank SMS often
        // includes a second amount for available/final balance; never pick that balance first.
        val patterns = listOf(
            Pattern.compile("\\b(?:debit(?:ed)?|credit(?:ed)?|withdrawn|deposited)\\s*[:=-]?\\s*(?:(?:INR)\\s*)?(?:Rs\\.?\\s*)?(?:₹\\s*)?([0-9][0-9,]*(?:\\.[0-9]{1,2})?)", Pattern.CASE_INSENSITIVE),
            Pattern.compile("(?:₹|\\bINR\\b|\\bRs\\.?\\s*)\\s*([0-9][0-9,]*(?:\\.[0-9]{1,2})?)", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\b(?:payment of|purchase of)\\s+(?:by|with|of)?\\s*(?:₹|INR|Rs\\.?\\s*)?([0-9][0-9,]*(?:\\.[0-9]{1,2})?)", Pattern.CASE_INSENSITIVE)
        )
        for (pattern in patterns) {
            val matcher = pattern.matcher(body)
            if (matcher.find()) {
                val amount = matcher.group(1)?.replace(",", "")?.toDoubleOrNull()
                if (amount != null && amount > 0.0) return amount
            }
        }
        return null
    }

    private fun detectDirection(body: String): String {
        val text = body.lowercase(Locale.ROOT)
        // Match bank wording such as "A/C XXXX Debit Rs.10.00" and "Credit:INR Rs.1.00".
        val debit = Regex("\\b(?:debit|debited|withdrawn|paid to|sent to|purchase of|spent)\\b", RegexOption.IGNORE_CASE)
            .containsMatchIn(body)
        val credit = Regex("\\b(?:credit|credited|deposited|received from)\\b", RegexOption.IGNORE_CASE)
            .containsMatchIn(body)
        return when {
            debit && !credit -> "debit"
            credit && !debit -> "credit"
            else -> "unknown"
        }
    }

    private fun extractMerchant(body: String): String {
        val patterns = listOf(
            Pattern.compile("(?:for\\s+UPI\\s+to|UPI\\s+to|paid to|sent to|transferred to|received from|at merchant|merchant)\\s*[:=-]?\\s*([^,.;\\n]+)", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\bto VPA\\s+([^,.;\\n]+)", Pattern.CASE_INSENSITIVE)
        )
        for (pattern in patterns) {
            val matcher = pattern.matcher(body)
            if (matcher.find()) {
                val candidate = matcher.group(1)?.trim().orEmpty()
                val cleaned = candidate
                    .replace(Regex("\\s+(?:on\\s+)?\\d{2}[-/]\\d{2}[-/]\\d{2,4}.*$", RegexOption.IGNORE_CASE), "")
                    .replace(Regex("\\s+(?:ref(?:erence)?|utr|avl\\s+bal|available\\s+balance|final\\s+balance)\\b.*$", RegexOption.IGNORE_CASE), "")
                    .trim()
                return cleaned.take(70).replace(Regex("\\s+"), " ")
            }
        }
        return ""
    }

    private fun extractReference(body: String): String {
        val pattern = Pattern.compile("(?:UPI\\s*(?:Ref(?:erence)?|RRN)|\\bRef(?:erence)?\\b|UTR|Txn(?:\\s*ID)?|Transaction\\s*ID)\\s*[:#=-]?\\s*([A-Za-z0-9-]{6,})", Pattern.CASE_INSENSITIVE)
        val matcher = pattern.matcher(body)
        return if (matcher.find()) matcher.group(1)?.take(50).orEmpty() else ""
    }


    /**
     * Return only a masked account hint, never a full account number. For a message like
     * "A/C XX1234" this returns "••••1234". If the account is fully masked (e.g. XXXXX),
     * no unique hint is available and an empty string is returned.
     */
    private fun extractAccountHint(body: String): String {
        val pattern = Pattern.compile("\\b(?:A/C|account)(?:\\s*(?:no\\.?|number))?\\s*[:#=-]?\\s*[Xx*•\\s]*([0-9]{2,4})\\b", Pattern.CASE_INSENSITIVE)
        val matcher = pattern.matcher(body)
        if (matcher.find()) return "••••" + matcher.group(1).orEmpty()
        return ""
    }

    private fun normalize(value: String): String =
        value.lowercase(Locale.ROOT).replace(Regex("\\s+"), " ").trim()

    private fun sha256(value: String): String {
        val bytes = MessageDigest.getInstance("SHA-256").digest(value.toByteArray(Charsets.UTF_8))
        return bytes.joinToString("") { "%02x".format(it) }
    }

    companion object {
        private const val TAG = "ExpolioSmsCapture"
        private const val PREFS = "expolio_sms_capture"
        private const val KEY_EVENTS = "captured_sms_events"
        private const val MAX_EVENTS = 100
        private const val NOTIFICATION_CHANNEL_ID = "expolio_transaction_capture"
        const val EXTRA_OPEN_AUTO_CAPTURE = "expolio_open_auto_capture"
        const val EXTRA_CAPTURE_EVENT_ID = "expolio_capture_event_id"

        @Synchronized
        private fun saveEvent(context: Context, event: JSONObject): Boolean {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val old = try {
                JSONArray(prefs.getString(KEY_EVENTS, "[]") ?: "[]")
            } catch (_: Exception) {
                JSONArray()
            }
            val fingerprint = event.optString("fingerprint")
            for (i in 0 until old.length()) {
                val previous = old.optJSONObject(i) ?: continue
                if (fingerprint.isNotBlank() && previous.optString("fingerprint") == fingerprint) return false
            }

            val updated = JSONArray()
            val start = maxOf(0, old.length() - (MAX_EVENTS - 1))
            for (i in start until old.length()) old.optJSONObject(i)?.let { updated.put(it) }
            updated.put(event)
            prefs.edit().putString(KEY_EVENTS, updated.toString()).apply()
            return true
        }

        fun getCapturedEvents(context: Context): List<Map<String, Any?>> {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val array = try {
                JSONArray(prefs.getString(KEY_EVENTS, "[]") ?: "[]")
            } catch (_: Exception) {
                JSONArray()
            }
            val result = mutableListOf<Map<String, Any?>>()
            for (i in 0 until array.length()) {
                val obj = array.optJSONObject(i) ?: continue
                result.add(
                    mapOf(
                        "id" to obj.optString("id"),
                        "source" to obj.optString("source", "sms"),
                        "appName" to obj.optString("appName", "Bank SMS"),
                        "amount" to obj.optDouble("amount", 0.0),
                        "direction" to obj.optString("direction", "unknown"),
                        "merchant" to obj.optString("merchant", ""),
                        "reference" to obj.optString("reference", ""),
                        "accountHint" to obj.optString("accountHint", ""),
                        "postedAt" to obj.optLong("postedAt"),
                        "capturedAt" to obj.optLong("capturedAt"),
                        "summary" to obj.optString("summary", "Bank transaction SMS matched")
                    )
                )
            }
            return result.reversed()
        }

        fun removeCapturedEvent(context: Context, eventId: String) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val old = try {
                JSONArray(prefs.getString(KEY_EVENTS, "[]") ?: "[]")
            } catch (_: Exception) {
                JSONArray()
            }
            val updated = JSONArray()
            for (i in 0 until old.length()) {
                val obj = old.optJSONObject(i) ?: continue
                if (obj.optString("id") != eventId) updated.put(obj)
            }
            prefs.edit().putString(KEY_EVENTS, updated.toString()).apply()
        }

        fun clearCapturedEvents(context: Context) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().remove(KEY_EVENTS).apply()
        }
    }
}
