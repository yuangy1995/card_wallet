package com.example.creditcard.ui.wallet

import androidx.compose.foundation.layout.Box
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountBalanceWallet
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CreditCard
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import com.example.creditcard.R

/** Empty-wallet action. Keep the popup anchored to its actual button, not the full-width empty state. */
@Composable
internal fun WalletAddFab(onAddCredit: () -> Unit, onAddDebit: () -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        ExtendedFloatingActionButton(onClick = { expanded = true },
            modifier = Modifier.testTag("wallet_add_fab"),
            icon = { Icon(Icons.Default.Add, null) },
            text = { Text(stringResource(R.string.add_card)) })
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false },
            modifier = Modifier.testTag("wallet_add_menu")) {
            DropdownMenuItem(text = { Text(stringResource(R.string.add_credit)) },
                leadingIcon = { Icon(Icons.Default.CreditCard, null) },
                onClick = { expanded = false; onAddCredit() })
            DropdownMenuItem(text = { Text(stringResource(R.string.add_debit)) },
                leadingIcon = { Icon(Icons.Default.AccountBalanceWallet, null) },
                onClick = { expanded = false; onAddDebit() })
        }
    }
}
