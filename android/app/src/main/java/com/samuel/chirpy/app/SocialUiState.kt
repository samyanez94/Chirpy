package com.samuel.chirpy.app

import com.samuel.chirpy.core.data.CurrentProfileState
import com.samuel.chirpy.core.model.Post
import com.samuel.chirpy.feature.postcomposer.PostComposerUiState
import com.samuel.chirpy.feature.postdetail.PostDetailUiState

data class SocialUiState(
    val profile: CurrentProfileState = CurrentProfileState(),
    val backStack: List<AppDestination> = listOf(AppDestination.Timeline),
    val selectedPost: Post? = null,
    val composer: PostComposerUiState = PostComposerUiState(),
    val detail: PostDetailUiState = PostDetailUiState(),
) {
    val destination: AppDestination get() = backStack.last()
}
