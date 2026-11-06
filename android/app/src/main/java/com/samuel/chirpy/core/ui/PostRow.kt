package com.samuel.chirpy.core.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import com.samuel.chirpy.R
import com.samuel.chirpy.core.model.Post
import java.time.Instant

@Composable
fun PostRow(
    post: Post,
    isUpdatingLike: Boolean,
    onLike: () -> Unit,
    formatDate: (Instant) -> String,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier.padding(horizontal = 20.dp, vertical = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            Modifier.size(44.dp)
                .clearAndSetSemantics {}
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.surfaceVariant),
            contentAlignment = Alignment.Center,
        ) {
            Text(post.author.displayName.take(1), style = MaterialTheme.typography.titleMedium)
            AsyncImage(
                model = post.author.avatarUrl,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.size(44.dp),
            )
        }
        Column(Modifier.weight(1f)) {
            FlowRow(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(
                    buildAnnotatedString {
                        withStyle(MaterialTheme.typography.titleSmall.toSpanStyle()) {
                            append(post.author.displayName)
                        }
                        append(" ")
                        withStyle(
                            MaterialTheme.typography.bodySmall
                                .toSpanStyle()
                                .copy(color = MaterialTheme.colorScheme.onSurfaceVariant),
                        ) {
                            append(stringResource(R.string.handle, post.author.username))
                        }
                    },
                    modifier = Modifier.padding(end = 8.dp).alignByBaseline(),
                )
                RelativePostDate(post.createdAt, formatDate, Modifier.alignByBaseline())
            }
            Spacer(Modifier.size(8.dp))
            Text(post.text, style = MaterialTheme.typography.bodyLarge)
            post.imageUrl?.let {
                Spacer(Modifier.size(8.dp))
                PostImage(it, post.author.displayName)
            }
            val action = stringResource(if (post.isLiked) R.string.unlike else R.string.like)
            val count = pluralStringResource(R.plurals.likes_count, post.likeCount, post.likeCount)
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier =
                Modifier.sizeIn(minWidth = 48.dp, minHeight = 48.dp)
                    .clickable(enabled = !isUpdatingLike, role = Role.Button, onClick = onLike)
                    .semantics {
                        contentDescription = action
                        stateDescription = count
                    },
            ) {
                Icon(
                    painterResource(
                        if (post.isLiked) R.drawable.ic_heart else R.drawable.ic_heart_outline,
                    ),
                    contentDescription = null,
                    modifier = Modifier.size(24.dp),
                    tint =
                    if (post.isLiked) {
                        MaterialTheme.colorScheme.error
                    } else {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    },
                )
                Spacer(Modifier.size(8.dp))
                Text(
                    post.likeCount.toString(),
                    style = MaterialTheme.typography.bodySmall,
                    color =
                    if (post.isLiked) {
                        MaterialTheme.colorScheme.error
                    } else {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    },
                )
            }
        }
    }
}
