package com.shibli.income_expence

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.Spinner
import android.widget.TextView
import android.widget.Toast
import com.google.firebase.FirebaseApp
import com.google.firebase.Timestamp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import org.json.JSONArray
import org.json.JSONObject
import java.util.Date
import java.util.Locale

/**
 * Native floating review card for a captured bank SMS.
 *
 * The user can choose a category and wallet and save without opening Flutter.
 * A deterministic Firestore document ID based on the SMS fingerprint prevents a second
 * save of the same captured event. The original SMS body is never stored or uploaded.
 */
class FloatingTransactionOverlayService : Service() {
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var saveInProgress = false

    private data class Choice(val id: String, val name: String, val type: String = "") {
        override fun toString(): String = name
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!Settings.canDrawOverlays(this)) {
            stopSelf(startId)
            return START_NOT_STICKY
        }
        val eventId = intent?.getStringExtra(SmsTransactionReceiver.EXTRA_CAPTURE_EVENT_ID).orEmpty()
        val event = findEvent(eventId) ?: run {
            stopSelf(startId)
            return START_NOT_STICKY
        }
        showOverlay(event)
        return START_NOT_STICKY
    }

    private fun findEvent(id: String): JSONObject? {
        val prefs = getSharedPreferences("expolio_sms_capture", Context.MODE_PRIVATE)
        val array = try { JSONArray(prefs.getString("captured_sms_events", "[]") ?: "[]") }
        catch (_: Exception) { JSONArray() }
        for (i in 0 until array.length()) {
            val obj = array.optJSONObject(i) ?: continue
            if (obj.optString("id") == id) return obj
        }
        return null
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private fun showOverlay(event: JSONObject) {
        removeOverlay()
        saveInProgress = false
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18), dp(16), dp(18), dp(14))
            background = GradientDrawable().apply {
                setColor(Color.rgb(250, 249, 245))
                cornerRadius = dp(22).toFloat()
                setStroke(dp(1), Color.rgb(210, 220, 215))
            }
            elevation = dp(12).toFloat()
        }
        val header = TextView(this).apply {
            text = "Expolio · Expense detected"
            setTextColor(Color.rgb(38, 83, 78))
            textSize = 14f
            setTypeface(typeface, Typeface.BOLD)
        }
        root.addView(header)

        val direction = event.optString("direction", "unknown")
        val isCredit = direction == "credit"
        val amount = event.optDouble("amount", 0.0)
        val amountView = TextView(this).apply {
            text = (if (isCredit) "+ ₹" else "₹") + String.format(Locale("en", "IN"), "%.2f", amount)
            setTextColor(if (isCredit) Color.rgb(28, 125, 79) else Color.rgb(39, 45, 44))
            textSize = 26f
            setTypeface(typeface, Typeface.BOLD)
            setPadding(0, dp(6), 0, dp(2))
        }
        root.addView(amountView)

        val merchant = event.optString("merchant").takeIf { it.isNotBlank() } ?: "Bank transaction"
        val detail = TextView(this).apply {
            text = when (direction) {
                "debit" -> "Money paid · $merchant"
                "credit" -> "Money received · $merchant"
                else -> "Transaction direction unclear. Open Expolio to review safely."
            }
            setTextColor(Color.rgb(91, 99, 96))
            textSize = 13f
        }
        root.addView(detail)

        val categoryLabel = sectionLabel("Category")
        root.addView(categoryLabel)
        val categorySpinner = Spinner(this)
        root.addView(categorySpinner, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(48)))

        val walletLabel = sectionLabel("Wallet / account")
        root.addView(walletLabel)
        val walletSpinner = Spinner(this)
        root.addView(walletSpinner, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(48)))

        val status = TextView(this).apply {
            text = "Loading your categories and wallets…"
            setTextColor(Color.rgb(91, 99, 96))
            textSize = 12f
            setPadding(0, dp(5), 0, dp(2))
        }
        root.addView(status)
        val progress = ProgressBar(this).apply { isIndeterminate = true }
        root.addView(progress, LinearLayout.LayoutParams(dp(28), dp(28)).apply {
            gravity = Gravity.CENTER_HORIZONTAL
            topMargin = dp(4)
            bottomMargin = dp(4)
        })

        val buttons = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END or Gravity.CENTER_VERTICAL
            setPadding(0, dp(8), 0, 0)
        }
        val later = Button(this).apply {
            text = "Later"
            isAllCaps = false
            setOnClickListener { removeOverlay(); stopSelf() }
        }
        val save = Button(this).apply {
            text = "Save transaction"
            isAllCaps = false
            isEnabled = false
        }
        buttons.addView(later)
        buttons.addView(save)
        root.addView(buttons)

        val eventId = event.optString("id")
        val eventFingerprint = event.optString("fingerprint")
        val transactionDirection = event.optString("direction", "unknown")
        val expectedCategoryType = when (transactionDirection) {
            "credit" -> "income"
            "debit" -> "expense"
            else -> ""
        }

        if (expectedCategoryType.isEmpty() || amount <= 0.0) {
            progress.visibility = View.GONE
            status.text = "Cannot safely save: amount or transaction direction is unclear. Tap Later and review in Expolio."
        } else {
            loadChoices(
                expectedCategoryType = expectedCategoryType,
                categorySpinner = categorySpinner,
                walletSpinner = walletSpinner,
                progress = progress,
                status = status,
                saveButton = save
            ) { categories, wallets ->
                save.setOnClickListener {
                    if (saveInProgress) return@setOnClickListener
                    val selectedCategory = categorySpinner.selectedItem as? Choice
                    val selectedWallet = walletSpinner.selectedItem as? Choice
                    if (selectedCategory == null || selectedWallet == null) {
                        status.text = "Choose a category and wallet first."
                        return@setOnClickListener
                    }
                    saveInProgress = true
                    save.isEnabled = false
                    later.isEnabled = false
                    status.text = "Saving to Expolio…"
                    saveTransaction(
                        event = event,
                        eventId = eventId,
                        fingerprint = eventFingerprint,
                        direction = transactionDirection,
                        merchant = merchant,
                        category = selectedCategory,
                        wallet = selectedWallet,
                        status = status,
                        saveButton = save,
                        laterButton = later
                    )
                }
            }
        }

        val windowType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            windowType,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = dp(45)
            x = dp(12)
            width = resources.displayMetrics.widthPixels - dp(24)
        }
        overlayView = root
        try { windowManager?.addView(root, params) }
        catch (_: Exception) { removeOverlay(); stopSelf() }
    }

    private fun sectionLabel(value: String): TextView = TextView(this).apply {
        text = value
        setTextColor(Color.rgb(38, 83, 78))
        textSize = 12f
        setTypeface(typeface, Typeface.BOLD)
        setPadding(0, dp(10), 0, 0)
    }

    private fun loadChoices(
        expectedCategoryType: String,
        categorySpinner: Spinner,
        walletSpinner: Spinner,
        progress: ProgressBar,
        status: TextView,
        saveButton: Button,
        onReady: (List<Choice>, List<Choice>) -> Unit
    ) {
        try {
            if (FirebaseApp.getApps(applicationContext).isEmpty()) {
                FirebaseApp.initializeApp(applicationContext)
            }
            val user = FirebaseAuth.getInstance().currentUser
            if (user == null) {
                progress.visibility = View.GONE
                status.text = "Open Expolio and sign in once, then try this transaction again."
                return
            }
            val db = FirebaseFirestore.getInstance()
            val userRef = db.collection("users").document(user.uid)
            var loadedCategories: List<Choice>? = null
            var loadedWallets: List<Choice>? = null
            var failed = false

            fun finishIfReady() {
                val categories = loadedCategories
                val wallets = loadedWallets
                if (failed || categories == null || wallets == null) return
                progress.visibility = View.GONE
                if (categories.isEmpty() || wallets.isEmpty()) {
                    status.text = if (categories.isEmpty()) "No matching category found. Add one in Expolio first."
                    else "No wallet found. Add a wallet in Expolio first."
                    saveButton.isEnabled = false
                    return
                }
                setSpinnerChoices(categorySpinner, categories)
                setSpinnerChoices(walletSpinner, wallets)
                status.text = "Choose a category and wallet, then save."
                saveButton.isEnabled = true
                onReady(categories, wallets)
            }

            userRef.collection("categories").get()
                .addOnSuccessListener { snapshot ->
                    loadedCategories = snapshot.documents.mapNotNull { doc ->
                        val data = doc.data ?: return@mapNotNull null
                        val type = data["type"] as? String ?: "expense"
                        if (type != expectedCategoryType) return@mapNotNull null
                        val name = data["name"] as? String ?: return@mapNotNull null
                        Choice(doc.id, name, type)
                    }.sortedBy { it.name.lowercase(Locale.ROOT) }
                    finishIfReady()
                }
                .addOnFailureListener { error ->
                    failed = true
                    progress.visibility = View.GONE
                    status.text = "Couldn't load categories: ${error.localizedMessage ?: "check internet"}"
                    saveButton.isEnabled = false
                }

            userRef.collection("wallets").get()
                .addOnSuccessListener { snapshot ->
                    loadedWallets = snapshot.documents.mapNotNull { doc ->
                        val name = doc.getString("name") ?: return@mapNotNull null
                        Choice(doc.id, name)
                    }.sortedBy { it.name.lowercase(Locale.ROOT) }
                    finishIfReady()
                }
                .addOnFailureListener { error ->
                    failed = true
                    progress.visibility = View.GONE
                    status.text = "Couldn't load wallets: ${error.localizedMessage ?: "check internet"}"
                    saveButton.isEnabled = false
                }
        } catch (error: Exception) {
            progress.visibility = View.GONE
            status.text = "Expolio couldn't connect to your account. Open the app and try again."
            saveButton.isEnabled = false
        }
    }

    private fun setSpinnerChoices(spinner: Spinner, choices: List<Choice>) {
        val adapter = ArrayAdapter(this, android.R.layout.simple_spinner_item, choices)
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        spinner.adapter = adapter
    }

    private fun saveTransaction(
        event: JSONObject,
        eventId: String,
        fingerprint: String,
        direction: String,
        merchant: String,
        category: Choice,
        wallet: Choice,
        status: TextView,
        saveButton: Button,
        laterButton: Button
    ) {
        try {
            if (FirebaseApp.getApps(applicationContext).isEmpty()) {
                FirebaseApp.initializeApp(applicationContext)
            }
            val user = FirebaseAuth.getInstance().currentUser
            if (user == null) throw IllegalStateException("Sign in to Expolio before saving.")
            val amount = event.optDouble("amount", 0.0)
            if (amount <= 0.0) throw IllegalArgumentException("The transaction amount is invalid.")

            val db = FirebaseFirestore.getInstance()
            val userId = user.uid
            val transactionId = "sms_" + (fingerprint.ifBlank { eventId }.take(56))
            val transactionRef = db.collection("users").document(userId)
                .collection("transactions").document(transactionId)
            val postedAt = event.optLong("postedAt", System.currentTimeMillis())
            val createdAt = Timestamp.now()
            val date = Timestamp(Date(postedAt))
            val reference = event.optString("reference").takeIf { it.isNotBlank() }
            val description = buildString {
                append(merchant.ifBlank { "Bank SMS transaction" })
                if (!reference.isNullOrBlank()) append(" · Ref $reference")
            }.take(180)
            val data: Map<String, Any> = hashMapOf<String, Any>(
                "userId" to userId,
                "amount" to amount,
                "type" to if (direction == "credit") "income" else "expense",
                "categoryId" to category.id,
                "categoryName" to category.name,
                "paymentMethod" to "upi",
                "description" to description,
                "date" to date,
                "createdAt" to createdAt,
                "walletId" to wallet.id,
                "walletName" to wallet.name,
                "fromWalletId" to "",
                "fromWalletName" to "",
                "toWalletId" to "",
                "toWalletName" to "",
                "source" to "sms_auto_capture"
            )

            db.runTransaction { transaction ->
                val existing = transaction.get(transactionRef)
                if (existing.exists()) {
                    false
                } else {
                    transaction.set(transactionRef, data)
                    true
                }
            }.addOnSuccessListener { created ->
                // Remove the local pending event only after Firestore confirms success or
                // confirms that the deterministic transaction document already exists.
                SmsTransactionReceiver.removeCapturedEvent(applicationContext, eventId)
                status.text = if (created) "Saved to Expolio successfully." else "This transaction was already saved."
                Toast.makeText(applicationContext, status.text, Toast.LENGTH_SHORT).show()
                removeOverlay()
                stopSelf()
            }.addOnFailureListener { error ->
                saveInProgress = false
                saveButton.isEnabled = true
                laterButton.isEnabled = true
                status.text = "Couldn't save: ${error.localizedMessage ?: "check connection and retry"}"
            }
        } catch (error: Exception) {
            saveInProgress = false
            saveButton.isEnabled = true
            laterButton.isEnabled = true
            status.text = "Couldn't save: ${error.localizedMessage ?: "open Expolio and sign in"}"
        }
    }

    private fun removeOverlay() {
        val view = overlayView ?: return
        try { windowManager?.removeView(view) } catch (_: Exception) { }
        overlayView = null
    }

    override fun onDestroy() {
        removeOverlay()
        windowManager = null
        super.onDestroy()
    }
}
