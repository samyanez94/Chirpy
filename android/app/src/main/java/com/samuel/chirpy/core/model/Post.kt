package com.samuel.chirpy.core.model

import java.time.Instant

data class Post(
    val id: String,
    val author: Profile,
    val text: String,
    val imageUrl: String?,
    val createdAt: Instant,
    val isLiked: Boolean,
    val likeCount: Int,
)
