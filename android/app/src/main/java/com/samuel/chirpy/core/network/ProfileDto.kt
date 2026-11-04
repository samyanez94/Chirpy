package com.samuel.chirpy.core.network

import com.samuel.chirpy.core.model.Profile
import kotlinx.serialization.Serializable

@Serializable
internal data class ProfileDto(
    val id: String,
    val username: String,
    val displayName: String,
    val avatarURL: String? = null,
) {
    fun toModel() = Profile(id, username, displayName, avatarURL)
}
