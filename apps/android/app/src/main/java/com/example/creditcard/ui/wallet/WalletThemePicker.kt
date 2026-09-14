package com.example.creditcard.ui.wallet

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.example.creditcard.R
import com.example.creditcard.utils.AppThemeMode
import com.example.creditcard.utils.ThemeManager

@Composable
internal fun WalletThemePicker() {
    val context = LocalContext.current
    val current by ThemeManager.themeMode.collectAsState()
    Row(Modifier.fillMaxWidth().testTag("wallet_theme_picker"), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        listOf(Triple(AppThemeMode.SYSTEM, R.string.theme_system, Icons.Default.PhoneAndroid),
            Triple(AppThemeMode.LIGHT, R.string.theme_light, Icons.Default.LightMode),
            Triple(AppThemeMode.DARK, R.string.theme_dark, Icons.Default.DarkMode)).forEach { (mode, label, icon) ->
            val checked = current == mode
            Surface(onClick = { ThemeManager.setThemeMode(context, mode) },
                modifier = Modifier.weight(1f).semantics { selected = checked }.testTag("wallet_theme_${mode.name}"),
                shape = RoundedCornerShape(14.dp),
                color = if (checked) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant,
                border = if (checked) BorderStroke(1.dp, MaterialTheme.colorScheme.primary) else null) {
                Box {
                    Column(Modifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 14.dp),
                        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(7.dp)) {
                        Icon(icon, null, Modifier.size(22.dp), tint = MaterialTheme.colorScheme.primary)
                        Text(stringResource(label), style = MaterialTheme.typography.labelMedium,
                            maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                    if (checked) Surface(modifier = Modifier.align(Alignment.TopEnd).padding(5.dp).size(16.dp),
                        shape = CircleShape, color = MaterialTheme.colorScheme.primary,
                        contentColor = MaterialTheme.colorScheme.onPrimary) {
                        Icon(Icons.Default.Check, stringResource(R.string.selected), Modifier.padding(2.dp))
                    }
                }
            }
        }
    }
}
