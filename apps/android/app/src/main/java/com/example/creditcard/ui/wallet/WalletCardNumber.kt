package com.example.creditcard.ui.wallet

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.creditcard.R

/** Actions never consume the number's width. Auto-size is native, not an onTextLayout/recompose loop. */
@Composable
internal fun WalletCardNumber(cardNumber: String, visible: Boolean, countdownProgress: Float,
    onToggleVisible: () -> Unit, onCopy: () -> Unit) {
    val digits = cardNumber.filter { it in '0'..'9' }
    val number = when {
        digits.isEmpty() -> "--"
        !visible -> "••••  ${walletLastFour(digits)}"
        else -> digits.chunked(4).joinToString(" ")
    }
    Column(Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(stringResource(R.string.wallet_card_number), style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.weight(1f))
            IconButton(onClick = onCopy, enabled = digits.isNotEmpty()) {
                Icon(Icons.Default.ContentCopy, stringResource(R.string.wallet_copy_number), Modifier.size(20.dp))
            }
            Box(contentAlignment = Alignment.Center) {
                if (visible) CircularProgressIndicator(progress = { countdownProgress }, modifier = Modifier.size(36.dp),
                    strokeWidth = 1.5.dp, color = MaterialTheme.colorScheme.primary.copy(alpha = 0.35f))
                IconButton(onClick = onToggleVisible, enabled = digits.isNotEmpty()) {
                    Icon(if (visible) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                        stringResource(if (visible) R.string.wallet_hide_number else R.string.wallet_show_number), Modifier.size(21.dp))
                }
            }
        }
        BasicText(number,
            modifier = Modifier.fillMaxWidth().heightIn(min = 40.dp).clickable(enabled = digits.isNotEmpty(), onClick = onCopy)
                .testTag("wallet_detail_number"),
            maxLines = 1, softWrap = false,
            autoSize = TextAutoSize.StepBased(minFontSize = 10.sp, maxFontSize = 22.sp, stepSize = 0.5.sp),
            style = MaterialTheme.typography.titleLarge.copy(fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.Medium, letterSpacing = 0.sp, color = MaterialTheme.colorScheme.onSurface))
        Text(stringResource(R.string.wallet_number_hint), style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
