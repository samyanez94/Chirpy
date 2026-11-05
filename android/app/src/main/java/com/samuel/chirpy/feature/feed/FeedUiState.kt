package com.samuel.chirpy.feature.feed

import com.samuel.chirpy.core.model.Post

data class FeedUiState(
    val posts: List<Post> = emptyList(),
    val isLoading: Boolean = true,
    val isRefreshing: Boolean = false,
    val isLoadingMore: Boolean = false,
    val nextCursor: String? = null,
    val initialError: FeedMessage? = null,
    val paginationFailed: Boolean = false,
    val pendingLikes: Set<String> = emptySet(),
    val message: FeedSnackbarMessage? = null,
)
