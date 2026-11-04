package com.samuel.chirpy.core.model

data class Profile(
    val id: String,
    val username: String,
    val displayName: String,
    val avatarUrl: String?,
)
