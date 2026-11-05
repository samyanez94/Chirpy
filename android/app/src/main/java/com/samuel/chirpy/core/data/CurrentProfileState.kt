package com.samuel.chirpy.core.data

import com.samuel.chirpy.core.model.Profile

data class CurrentProfileState(
    val profile: Profile? = null,
    val isLoading: Boolean = false,
    val hasFailed: Boolean = false,
)
