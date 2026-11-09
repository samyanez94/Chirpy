package com.samuel.chirpy.feature.feed

import androidx.compose.runtime.Composable
import com.samuel.chirpy.core.model.Post

@Composable
internal fun Timeline(
    state: FeedUiState,
    onRefresh: () -> Unit,
    onLoadMore: () -> Unit,
    onLike: (String) -> Unit,
    onMessageDismissed: (Long) -> Unit,
    onPost: (Post) -> Unit,
) {
    FeedScreen(
        state = state,
        onRefresh = onRefresh,
        onLoadMore = onLoadMore,
        onLike = onLike,
        onMessageDismissed = onMessageDismissed,
        onPost = onPost,
        showToolbar = false,
    )
}
