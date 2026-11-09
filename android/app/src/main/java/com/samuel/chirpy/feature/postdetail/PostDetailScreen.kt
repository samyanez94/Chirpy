package com.samuel.chirpy.feature.postdetail

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.samuel.chirpy.R
import com.samuel.chirpy.core.data.CurrentProfileState
import com.samuel.chirpy.core.ui.PostRow
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun PostDetailScreen(
    state: PostDetailUiState,
    profile: CurrentProfileState,
    onLike: () -> Unit,
    onDelete: () -> Unit,
    onClose: () -> Unit,
    onRetryProfile: () -> Unit,
) {
    val post = state.post ?: return
    var confirmDelete by rememberSaveable(post.id) { mutableStateOf(false) }
    val busy = state.isBusy
    Scaffold(topBar = {
        TopAppBar(
            title = { Text(stringResource(R.string.post_detail)) },
            navigationIcon = {
                IconButton(onClick = onClose, enabled = !busy) {
                    Icon(painterResource(R.drawable.ic_arrow_back), stringResource(R.string.back))
                }
            },
            actions = {
                if (profile.profile?.id == post.author.id) {
                    TextButton(onClick = {
                        confirmDelete = true
                    }, enabled = !busy) { Text(stringResource(R.string.delete_post)) }
                }
            },
        )
    }) { padding ->
        Column(Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState())) {
            SelectionContainer {
                PostRow(post, busy, onLike, { instant ->
                    DateTimeFormatter.ofLocalizedDateTime(
                        FormatStyle.MEDIUM,
                    ).withZone(ZoneId.systemDefault()).format(instant)
                })
            }
            if (state.hasFailed) {
                Text(
                    stringResource(R.string.mutation_failed),
                    Modifier.padding(16.dp),
                )
            }
            if (profile.hasFailed) {
                TextButton(onClick = onRetryProfile) {
                    Text(stringResource(R.string.retry_profile))
                }
            }
        }
    }
    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text(stringResource(R.string.delete_post)) },
            text = { Text(stringResource(R.string.delete_confirmation)) },
            confirmButton = {
                TextButton(onClick = {
                    confirmDelete = false
                    onDelete()
                }) { Text(stringResource(R.string.delete_post)) }
            },
            dismissButton = {
                TextButton(onClick = {
                    confirmDelete = false
                }) { Text(stringResource(R.string.cancel)) }
            },
        )
    }
}
