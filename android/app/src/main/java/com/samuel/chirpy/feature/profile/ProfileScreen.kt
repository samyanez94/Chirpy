package com.samuel.chirpy.feature.profile

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import com.samuel.chirpy.R
import com.samuel.chirpy.core.data.CurrentProfileState

@Composable
internal fun ProfileScreen(
    state: CurrentProfileState,
    onRetry: () -> Unit,
    content: @Composable () -> Unit,
) {
    Column {
        Row(
            Modifier.fillMaxWidth().padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            state.profile?.let { profile ->
                AsyncImage(
                    profile.avatarUrl,
                    null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.size(56.dp).clip(CircleShape),
                )
                Column {
                    Text(profile.displayName, style = MaterialTheme.typography.titleLarge)
                    Text(stringResource(R.string.handle, profile.username))
                }
            }
            if (state.isLoading) CircularProgressIndicator()
            if (state.hasFailed) {
                Button(
                    onClick = onRetry,
                    colors = ButtonDefaults.buttonColors(contentColor = Color.White),
                ) { Text(stringResource(R.string.retry_profile)) }
            }
        }
        content()
    }
}
