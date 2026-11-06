package com.samuel.chirpy.feature.social

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.samuel.chirpy.R

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun ComposerScreen(
    state: ComposerUiState,
    onEdit: (String) -> Unit,
    onPublish: () -> Unit,
    onClose: () -> Unit,
) {
    Scaffold(topBar = {
        TopAppBar(
            title = { Text(stringResource(R.string.new_post)) },
            navigationIcon = {
                IconButton(onClick = onClose, enabled = !state.isPosting) {
                    Icon(painterResource(R.drawable.ic_close), stringResource(R.string.close))
                }
            },
            actions = {
                TextButton(onClick = onPublish, enabled = state.canPublish) {
                    Text(stringResource(R.string.publish))
                }
            },
        )
    }) { padding ->
        Column(
            Modifier.fillMaxSize()
                .padding(padding)
                .consumeWindowInsets(padding)
                .imePadding()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
        ) {
            OutlinedTextField(
                state.draft,
                onEdit,
                enabled = !state.isPosting,
                label = { Text(stringResource(R.string.post_text)) },
                placeholder = { Text(stringResource(R.string.post_prompt)) },
                modifier = Modifier.fillMaxWidth(),
                minLines = 5,
            )
            Text(
                stringResource(
                    R.string.character_count,
                    state.characterCount,
                    state.characterLimit,
                ),
                color = if (state.isOverLimit) {
                    MaterialTheme.colorScheme.error
                } else {
                    MaterialTheme.colorScheme.onSurface
                },
            )
            if (state.isPosting) CircularProgressIndicator()
            if (state.hasFailed) {
                Text(
                    stringResource(R.string.post_failed),
                    color = MaterialTheme.colorScheme.error,
                )
            }
        }
    }
}
