package com.samuel.chirpy.core.network

import kotlinx.serialization.Serializable

@Serializable
internal data class LikeUpdateDto(val postID: String, val isLiked: Boolean, val likeCount: Int)
