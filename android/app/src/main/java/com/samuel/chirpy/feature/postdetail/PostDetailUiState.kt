package com.samuel.chirpy.feature.postdetail

import com.samuel.chirpy.core.model.Post

data class PostDetailUiState(
    val post: Post? = null,
    val isLiking: Boolean = false,
    val isDeleting: Boolean = false,
    val hasFailed: Boolean = false,
    val isPending: Boolean = false,
) {
    val isBusy: Boolean get() = isLiking || isDeleting || isPending
}
