package com.samuel.chirpy.core.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import com.samuel.chirpy.R

@Composable
fun PostImage(url: String, author: String) {
    var failed by remember(url) { mutableStateOf(false) }
    Box(
        Modifier.fillMaxWidth()
            .aspectRatio(16f / 9f)
            .clip(RoundedCornerShape(12.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant),
        contentAlignment = Alignment.Center,
    ) {
        if (failed) {
            Text(
                stringResource(R.string.image_unavailable),
                style = MaterialTheme.typography.labelMedium,
            )
        }
        AsyncImage(
            model = url,
            contentDescription = stringResource(R.string.post_image, author),
            contentScale = ContentScale.Crop,
            modifier = Modifier.matchParentSize(),
            onError = { failed = true },
            onSuccess = { failed = false },
        )
    }
}
