package com.samuel.chirpy.feature.social

data class DetailUiState(
    val isLiking: Boolean = false,
    val isDeleting: Boolean = false,
    val hasFailed: Boolean = false,
    val isPending: Boolean = false,
) {
    val isBusy: Boolean get() = isLiking || isDeleting || isPending
}
