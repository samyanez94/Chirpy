package com.samuel.chirpy.app

import com.samuel.chirpy.core.data.CurrentProfileState

data class SocialUiState(
    val profile: CurrentProfileState = CurrentProfileState(),
    val backStack: List<AppDestination> = listOf(AppDestination.Timeline),
) {
    val destination: AppDestination get() = backStack.last()
}
