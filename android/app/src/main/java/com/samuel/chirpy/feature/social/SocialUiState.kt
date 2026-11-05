package com.samuel.chirpy.feature.social

import com.samuel.chirpy.core.data.CurrentProfileState
import com.samuel.chirpy.core.model.Post

data class SocialUiState(
    val profile: CurrentProfileState = CurrentProfileState(),
    val backStack: List<SocialDestination> = listOf(SocialDestination.Timeline),
    val selectedPost: Post? = null,
    val composer: ComposerUiState = ComposerUiState(),
    val detail: DetailUiState = DetailUiState(),
) {
    val destination: SocialDestination get() = backStack.last()
}
