package com.samuel.chirpy.feature.social

import androidx.compose.runtime.Composable
import com.samuel.chirpy.core.model.Post
import com.samuel.chirpy.feature.feed.FeedScreen
import com.samuel.chirpy.feature.feed.FeedUiState

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
