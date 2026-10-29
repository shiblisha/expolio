package com.shibli.income_expence

import android.app.Notification
import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID
import java.util.regex.Pattern

/**
 * Proof-of-concept notification capture.
 *
 * Only checks notifications from the payment/banking package allowlist below.
 * Extracted data is kept on-device until the user reviews it in Expolio.
 * Nothing is sent to Firebase by this service.
 */
class NotificationCaptureService : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        try {
            val packageName = sbn.packageName ?: return
            if (!SUPPORTED_PACKAGES.contains(packageName)) return

            val extras = sbn.notification.extras ?: return
            val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
            val text = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
                ?.takeIf { it.isNotBlank() }
                ?: extras.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()

            val lines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
                ?.joinToString(" ") { it.toString() }
                .orEmpty()

            val fullText = listOf(title, text, lines)
                .filter { it.isNotBlank() }
                .distinct()
                .joinToString(" • ")
                .trim()

            if (fullText.isBlank()) return
            if (!looksLikeTransaction(fullText)) return

            val amount = extractAmount(fullText) ?: return
            val direction = detectDirection(fullText)
            val merchant = extractMerchant(fullText)
            val appName = try {
                packageManager.getApplicationLabel(
                    packageManager.getApplicationInfo(packageName, 0)
                ).toString()
            } catch (_: Exception) {
                packageName
            }

            val event = JSONObject().apply {
                put("id", UUID.randomUUID().toString())
                put("packageName", packageName)
                put("appName", appName)
                put("title", title)
                put("text", fullText.take(600))
                put("amount", amount)
                put("direction", direction)
                put("merchant", merchant)
                put("postedAt", sbn.postTime)
                put("capturedAt", System.currentTimeMillis())
            }

            saveEvent(applicationContext, event)
        } catch (e: Exception) {
            Log.w(TAG, "Could not parse payment notification", e)
        }
    }

    private fun looksLikeTransaction(text: String): Boolean {
        val lower = text.lowercase(Locale.ROOT)
        val keywords = listOf(
            "paid", "payment", "debited", "debit", "credited", "credit",
            "received", "sent", "spent", "transferred", "transaction",
            "upi", "withdrawn", "purchase", "successful"
        )
        return keywords.any { lower.contains(it) }
    }

    private fun extractAmount(text: String): Double? {
        // Examples: ₹1,250.00, Rs. 450, INR 120.50
        val patterns = listOf(
            Pattern.compile("(?:₹|\\bINR\\b|\\bRs\\.?\\s*)\\s*([0-9][0-9,]*(?:\\.[0-9]{1,2})?)", Pattern.CASE_INSENSITIVE),
            Pattern.compile("\\b(?:paid|payment|debited|credited|received|sent|spent)\\s+(?:of\\s+)?(?:₹|Rs\\.?\\s*)?([0-9][0-9,]*(?:\\.[0-9]{1,2})?)", Pattern.CASE_INSENSITIVE)
        )
        for (pattern in patterns) {
            val matcher = pattern.matcher(text)
            if (matcher.find()) {
                val parsed = matcher.group(1)?.replace(",", "")?.toDoubleOrNull()
                if (parsed != null && parsed > 0) return parsed
            }
        }
        return null
    }

    private fun detectDirection(text: String): String {
        val lower = text.lowercase(Locale.ROOT)
        val debitWords = listOf("debited", "debit", "paid", "sent", "spent", "withdrawn", "purchase")
        val creditWords = listOf("credited", "credit", "received")
        val debit = debitWords.any { lower.contains(it) }
        val credit = creditWords.any { lower.contains(it) }

        // Ambiguous notifications are not automatically treated as an expense.
        return when {
            debit && !credit -> "debit"
            credit && !debit -> "credit"
            else -> "unknown"
        }
    }

    private fun extractMerchant(text: String): String {
        val patterns = listOf(
            Pattern.compile("(?:paid to|payment to|sent to|transferred to|at)\\s+([^•,.;]+)", Pattern.CASE_INSENSITIVE),
            Pattern.compile("(?:from)\\s+([^•,.;]+)", Pattern.CASE_INSENSITIVE)
        )
        for (pattern in patterns) {
            val matcher = pattern.matcher(text)
            if (matcher.find()) {
                return matcher.group(1)?.trim()?.take(80).orEmpty()
            }
        }
        return ""
    }

    companion object {
        private const val TAG = "ExpolioAutoCapture"
        private const val PREFS = "expolio_notification_capture"
        private const val KEY_EVENTS = "captured_events"
        private const val MAX_EVENTS = 100

        // Common India payment apps and bank apps. This is intentionally an
        // allowlist; Expolio must not collect every notification on the device.
        private val SUPPORTED_PACKAGES = setOf(
            "com.google.android.apps.nbu.paisa.user", // Google Pay
            "com.phonepe.app",                        // PhonePe
            "net.one97.paytm",                        // Paytm
            "in.org.npci.upiapp",                     // BHIM
            "com.sbi.lotusintouch",                   // SBI YONO (package may vary by release)
            "com.snapwork.hdfc",                      // HDFC Bank (package may vary)
            "com.csam.icici.bank.imobile",            // ICICI iMobile
            "com.axis.mobile",                        // Axis Mobile (package may vary)
            "org.kotak.bank.mobile"                   // Kotak Mobile (package may vary)
        )

        @Synchronized
        private fun saveEvent(context: Context, event: JSONObject) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val old = try {
                JSONArray(prefs.getString(KEY_EVENTS, "[]") ?: "[]")
            } catch (_: Exception) {
                JSONArray()
            }

            // Avoid repeated callbacks for the same notification.
            val packageName = event.optString("packageName")
            val title = event.optString("title")
            val text = event.optString("text")
            val postedAt = event.optLong("postedAt")
            for (i in 0 until old.length()) {
                val previous = old.optJSONObject(i) ?: continue
                if (previous.optString("packageName") == packageName &&
                    previous.optString("title") == title &&
                    previous.optString("text") == text &&
                    kotlin.math.abs(previous.optLong("postedAt") - postedAt) < 5000L
                ) return
            }

            val updated = JSONArray()
            val start = maxOf(0, old.length() - (MAX_EVENTS - 1))
            for (i in start until old.length()) {
                old.optJSONObject(i)?.let { updated.put(it) }
            }
            updated.put(event)
            prefs.edit().putString(KEY_EVENTS, updated.toString()).apply()
        }

        fun getCapturedNotifications(context: Context): List<Map<String, Any?>> {
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
                        "packageName" to obj.optString("packageName"),
                        "appName" to obj.optString("appName"),
                        "title" to obj.optString("title"),
                        "text" to obj.optString("text"),
                        "amount" to obj.optDouble("amount", 0.0),
                        "direction" to obj.optString("direction", "unknown"),
                        "merchant" to obj.optString("merchant"),
                        "postedAt" to obj.optLong("postedAt"),
                        "capturedAt" to obj.optLong("capturedAt")
                    )
                )
            }
            return result.reversed()
        }

        fun clearCapturedNotifications(context: Context) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .remove(KEY_EVENTS)
                .apply()
        }
    }
}
