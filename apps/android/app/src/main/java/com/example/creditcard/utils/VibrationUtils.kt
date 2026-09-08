package com.example.creditcard.utils

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.content.ContextCompat

object VibrationUtils {
    fun vibrate(context: Context, durationMs: Long) {
        val vibrator = defaultVibrator(context) ?: return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                vibrateLegacy(vibrator, durationMs)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun vibratePattern(context: Context, pattern: LongArray, repeat: Int = -1) {
        val vibrator = defaultVibrator(context) ?: return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createWaveform(pattern, repeat))
            } else {
                vibratePatternLegacy(vibrator, pattern, repeat)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun defaultVibrator(context: Context): Vibrator? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(VibratorManager::class.java)?.defaultVibrator
        } else {
            ContextCompat.getSystemService(context, Vibrator::class.java)
        }
    }

    @Suppress("DEPRECATION")
    private fun vibrateLegacy(vibrator: Vibrator, durationMs: Long) {
        vibrator.vibrate(durationMs)
    }

    @Suppress("DEPRECATION")
    private fun vibratePatternLegacy(vibrator: Vibrator, pattern: LongArray, repeat: Int) {
        vibrator.vibrate(pattern, repeat)
    }
}
