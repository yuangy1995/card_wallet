package com.example.creditcard.utils

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.example.creditcard.MainActivity
import com.example.creditcard.R
import com.example.creditcard.data.SharedCard
import java.time.LocalDate

object CardSystemNotifier {
    private const val CHANNEL_ID = "card_reminders"
    private const val PREFS = "card_system_notifications"
    private const val LAST_FINGERPRINT = "last_fingerprint"
    private const val NOTIFICATION_ID = 4201

    fun notifyDailySummary(context: Context, cards: List<SharedCard>, force: Boolean = false): Boolean {
        if (!canNotify(context)) return false

        val billingItems = CardReminderRules.billingCycleAlerts(cards)
        val repaymentCount = billingItems.count { it.second.kind == BillingCycleReminderKind.REPAYMENT }
        val billCount = billingItems.count { it.second.kind == BillingCycleReminderKind.BILL }
        val annualCount = cards.count { CardReminderRules.annualFeeDetection(it) != null }
        val expiryCount = CardReminderRules.cardExpiryAlerts(cards).size
        val total = repaymentCount + billCount + annualCount + expiryCount
        if (total <= 0) return false

        val fingerprint = listOf(LocalDate.now(), repaymentCount, billCount, annualCount, expiryCount).joinToString("|")
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!force && prefs.getString(LAST_FINGERPRINT, "") == fingerprint) return false

        ensureChannel(context)
        val intent = Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val body = listOfNotNull(
            if (repaymentCount > 0) "还款 ${repaymentCount} 项" else null,
            if (billCount > 0) "账单 ${billCount} 项" else null,
            if (annualCount > 0) "年费 ${annualCount} 项" else null,
            if (expiryCount > 0) "有效期 ${expiryCount} 项" else null
        ).joinToString(" / ")

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle("卡片提醒")
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
        prefs.edit().putString(LAST_FINGERPRINT, fingerprint).apply()
        return true
    }

    fun canNotify(context: Context): Boolean {
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) return false
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "卡片提醒",
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = "还款日、账单日、年费和有效期提醒"
        }
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }
}
