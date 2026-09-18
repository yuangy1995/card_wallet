package com.example.creditcard.ui.wallet

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import java.time.LocalDate

/** A screen-level date signal; no per-card clocks, and refreshes after sleep/time-zone changes. */
@Composable
internal fun rememberCalendarDay(): LocalDate {
    val context = LocalContext.current
    val owner = LocalLifecycleOwner.current
    var day by remember { mutableStateOf(LocalDate.now()) }
    DisposableEffect(context, owner) {
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) { day = LocalDate.now() }
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_DATE_CHANGED)
            addAction(Intent.ACTION_TIME_CHANGED)
            addAction(Intent.ACTION_TIMEZONE_CHANGED)
        }
        ContextCompat.registerReceiver(context, receiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) day = LocalDate.now()
        }
        owner.lifecycle.addObserver(observer)
        onDispose {
            context.unregisterReceiver(receiver)
            owner.lifecycle.removeObserver(observer)
        }
    }
    return day
}
