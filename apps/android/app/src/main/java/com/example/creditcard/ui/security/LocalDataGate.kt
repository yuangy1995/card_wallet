package com.example.creditcard.ui.security

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.example.creditcard.R
import com.example.creditcard.utils.LocalCardLoadState

/** Empty-wallet actions are only available after a successful local read, not during unlocking. */
@Composable
internal fun LocalDataGate(
    state: LocalCardLoadState,
    onRetry: () -> Unit,
    content: @Composable () -> Unit
) {
    if (state == LocalCardLoadState.READY) {
        content()
        return
    }
    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp).testTag("local_data_gate"),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically)
    ) {
        if (state == LocalCardLoadState.FAILED) {
            Text(
                stringResource(R.string.local_cards_load_failed),
                color = MaterialTheme.colorScheme.onSurface,
                style = MaterialTheme.typography.bodyLarge,
                textAlign = TextAlign.Center
            )
            TextButton(onClick = onRetry, modifier = Modifier.testTag("local_data_retry")) {
                Text(stringResource(R.string.local_cards_retry))
            }
        } else {
            CircularProgressIndicator()
            Text(
                stringResource(R.string.local_cards_loading),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodyLarge
            )
        }
    }
}
