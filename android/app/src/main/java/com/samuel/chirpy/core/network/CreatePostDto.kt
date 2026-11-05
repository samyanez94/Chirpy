package com.samuel.chirpy.core.network

import kotlinx.serialization.Serializable

@Serializable
internal data class CreatePostDto(val text: String)
