package com.example.creditcard.utils

import android.content.Context
import android.content.ContextWrapper
import android.content.pm.PackageManager
import android.os.Build
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity

object BiometricAuthHelper {
    private const val AUTHENTICATORS =
        BiometricManager.Authenticators.BIOMETRIC_STRONG or BiometricManager.Authenticators.BIOMETRIC_WEAK

    fun canAuthenticate(context: Context): Boolean {
        return BiometricManager.from(context.applicationContext).canAuthenticate(AUTHENTICATORS) ==
            BiometricManager.BIOMETRIC_SUCCESS
    }

    fun modalityLabel(context: Context): String {
        val packageManager = context.applicationContext.packageManager
        val hasFingerprint = packageManager.hasSystemFeature(PackageManager.FEATURE_FINGERPRINT)
        val hasFace = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_FACE)
        val hasIris = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_IRIS)

        return when {
            hasFingerprint && !hasFace && !hasIris -> "指纹识别"
            hasFace && !hasFingerprint && !hasIris -> "人脸识别"
            hasIris && !hasFingerprint && !hasFace -> "虹膜识别"
            else -> "生物识别"
        }
    }

    fun unlockLabel(context: Context): String = "使用${modalityLabel(context)}解锁"

    fun availabilityMessage(context: Context): String {
        val label = modalityLabel(context)
        return when (BiometricManager.from(context.applicationContext).canAuthenticate(AUTHENTICATORS)) {
            BiometricManager.BIOMETRIC_SUCCESS -> "当前设备支持${label}解锁"
            BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> "当前手机不支持生物识别"
            BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE -> "生物识别硬件暂不可用"
            BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> "请先在系统设置中录入可用的生物识别信息"
            else -> "当前设备暂不支持生物识别解锁"
        }
    }

    fun authenticate(
        activity: FragmentActivity,
        title: String,
        subtitle: String,
        negativeButtonText: String = "使用数字密码",
        onSuccess: () -> Unit,
        onError: (String) -> Unit
    ) {
        val executor = ContextCompat.getMainExecutor(activity)
        val prompt = BiometricPrompt(
            activity,
            executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    onSuccess()
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    onError(errString.toString())
                }

                override fun onAuthenticationFailed() {
                    onError("未能完成生物识别，请重试")
                }
            }
        )

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle(title)
            .setSubtitle(subtitle)
            .setNegativeButtonText(negativeButtonText)
            .setAllowedAuthenticators(AUTHENTICATORS)
            .build()
        prompt.authenticate(promptInfo)
    }
}

fun Context.findFragmentActivity(): FragmentActivity? {
    var current: Context? = this
    while (current is ContextWrapper) {
        if (current is FragmentActivity) return current
        current = current.baseContext
    }
    return current as? FragmentActivity
}
