package com.samuel.chirpy.feature.social

import com.samuel.chirpy.core.data.CurrentProfileState

data class SocialUiState(
    val profile: CurrentProfileState = CurrentProfileState(),
    val destination: SocialDestination = SocialDestination.Timeline,
    val composer: ComposerUiState = ComposerUiState(),
    val detail: DetailUiState = DetailUiState(),
)
