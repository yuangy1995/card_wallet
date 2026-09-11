package com.example.creditcard.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.example.creditcard.R

/** 详情、表单与设置共用的轻量分组；只在展开状态改变时运行原生动效。 */
@Composable
fun WalletSection(
    title: String,
    expanded: Boolean = true,
    onExpandedChange: ((Boolean) -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit
) {
    Surface(shape = MaterialTheme.shapes.large, color = MaterialTheme.colorScheme.surface) {
        Column(Modifier.fillMaxWidth()) {
            if (title.isNotBlank()) {
                val rotation = animateFloatAsState(if (expanded) 180f else 0f, tween(200), label = "sectionChevron")
                Row(
                    Modifier.fillMaxWidth()
                        .then(if (onExpandedChange != null) Modifier.clickable { onExpandedChange(!expanded) } else Modifier)
                        .heightIn(min = 56.dp).padding(horizontal = 20.dp, vertical = 16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(title, style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                    if (onExpandedChange != null) {
                        Icon(Icons.Default.ExpandMore,
                            stringResource(if (expanded) R.string.collapse else R.string.expand),
                            Modifier.graphicsLayer { rotationZ = rotation.value },
                            tint = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
            AnimatedVisibility(
                visible = expanded,
                enter = expandVertically(tween(220)) + fadeIn(tween(160)),
                exit = shrinkVertically(tween(180)) + fadeOut(tween(120))
            ) {
                Column(Modifier.fillMaxWidth().padding(start = 20.dp, end = 20.dp, bottom = 20.dp)) { content() }
            }
        }
    }
}
