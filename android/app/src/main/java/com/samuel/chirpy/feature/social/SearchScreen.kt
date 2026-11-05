package com.samuel.chirpy.feature.social

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.key
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.samuel.chirpy.R

@Composable
internal fun SearchScreen(
    text: String,
    onQueryChange: (String) -> Unit,
    content: @Composable () -> Unit,
) {
    Column {
        OutlinedTextField(
            value = text,
            onValueChange = onQueryChange,
            label = { Text(stringResource(R.string.search_posts)) },
            singleLine = true,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
        )
        if (text.isBlank()) {
            Text(stringResource(R.string.search_prompt), Modifier.padding(24.dp))
        } else {
            key(text.trim()) {
                content()
            }
        }
    }
}
