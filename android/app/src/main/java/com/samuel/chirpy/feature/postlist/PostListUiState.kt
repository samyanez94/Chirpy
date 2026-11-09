package com.samuel.chirpy.feature.postlist

import com.samuel.chirpy.core.model.Post

data class PostListUiState(
    val posts: List<Post> = emptyList(),
    val isLoading: Boolean = true,
    val isRefreshing: Boolean = false,
    val isLoadingMore: Boolean = false,
    val nextCursor: String? = null,
    val initialError: PostListMessage? = null,
    val paginationFailed: Boolean = false,
    val pendingLikes: Set<String> = emptySet(),
    val message: PostListSnackbarMessage? = null,
)
