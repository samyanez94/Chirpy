package com.samuel.chirpy.core.model

data class LikeUpdate(val postId: String, val isLiked: Boolean, val likeCount: Int)
