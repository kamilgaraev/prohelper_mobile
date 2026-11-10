package ru.prohelper.prohelpers_mobile

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

class BiometricUnlockHandler(
    private val activity: FragmentActivity,
) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "most.android.biometric"
        private const val KEY_ALIAS = "most_quick_unlock_biometric"
        private const val KEYSTORE = "AndroidKeyStore"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
    }

    private var inFlight = false

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "availability" -> result.success(availability())
            "enable" -> start(call, result, createKey = true)
            "authenticate" -> start(call, result, createKey = false)
            "disable" -> {
                deleteKey()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun availability(): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return "unavailable"
        return when (BiometricManager.from(activity).canAuthenticate(BIOMETRIC_STRONG)) {
            BiometricManager.BIOMETRIC_SUCCESS -> "available"
            BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> "not_enrolled"
            else -> "unavailable"
        }
    }

    private fun start(call: MethodCall, result: MethodChannel.Result, createKey: Boolean) {
        if (inFlight) {
            result.success("failed")
            return
        }
        if (availability() != "available") {
            result.success("unavailable")
            return
        }

        val cipher = try {
            if (createKey) {
                deleteKey()
                generateKey()
            } else if (!hasKey()) {
                result.success("invalidated")
                return
            }
            Cipher.getInstance(TRANSFORMATION).apply { init(Cipher.ENCRYPT_MODE, loadKey()) }
        } catch (_: KeyPermanentlyInvalidatedException) {
            deleteKey()
            result.success("invalidated")
            return
        } catch (_: Exception) {
            if (createKey) deleteKey()
            result.success(if (createKey) "unavailable" else "failed")
            return
        }

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle(call.argument<String>("title") ?: "")
            .setSubtitle(call.argument<String>("subtitle"))
            .setNegativeButtonText(call.argument<String>("cancel") ?: "")
            .setAllowedAuthenticators(BIOMETRIC_STRONG)
            .setConfirmationRequired(false)
            .build()

        inFlight = true
        var replied = false
        fun reply(value: String) {
            if (replied) return
            replied = true
            inFlight = false
            result.success(value)
        }

        val prompt = BiometricPrompt(
            activity,
            ContextCompat.getMainExecutor(activity),
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                    val unlockedCipher = authResult.cryptoObject?.cipher
                    val confirmed = try {
                        unlockedCipher?.doFinal(byteArrayOf(1))
                        unlockedCipher != null
                    } catch (_: Exception) {
                        false
                    }
                    if (!confirmed && createKey) deleteKey()
                    reply(if (confirmed) "success" else "failed")
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    if (createKey) deleteKey()
                    reply(
                        when (errorCode) {
                            BiometricPrompt.ERROR_LOCKOUT,
                            BiometricPrompt.ERROR_LOCKOUT_PERMANENT -> "locked_out"
                            BiometricPrompt.ERROR_USER_CANCELED,
                            BiometricPrompt.ERROR_NEGATIVE_BUTTON,
                            BiometricPrompt.ERROR_CANCELED -> "cancelled"
                            BiometricPrompt.ERROR_NO_BIOMETRICS,
                            BiometricPrompt.ERROR_HW_NOT_PRESENT,
                            BiometricPrompt.ERROR_HW_UNAVAILABLE -> "unavailable"
                            else -> "failed"
                        },
                    )
                }
            },
        )

        try {
            prompt.authenticate(promptInfo, BiometricPrompt.CryptoObject(cipher))
        } catch (_: Exception) {
            if (createKey) deleteKey()
            reply("failed")
        }
    }

    private fun keyStore(): KeyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }

    private fun hasKey(): Boolean = try {
        keyStore().containsAlias(KEY_ALIAS)
    } catch (_: Exception) {
        false
    }

    private fun loadKey(): SecretKey = keyStore().getKey(KEY_ALIAS, null) as SecretKey

    private fun generateKey() {
        val spec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setUserAuthenticationRequired(true)
            .setInvalidatedByBiometricEnrollment(true)
            .build()
        KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE).apply {
            init(spec)
            generateKey()
        }
    }

    private fun deleteKey() {
        try {
            keyStore().deleteEntry(KEY_ALIAS)
        } catch (_: Exception) {
        }
    }
}
