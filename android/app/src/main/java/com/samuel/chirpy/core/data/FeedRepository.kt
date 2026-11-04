package com.samuel.chirpy.core.data

import com.samuel.chirpy.core.model.FeedPage
import com.samuel.chirpy.core.model.LikeUpdate

interface FeedRepository {
    suspend fun fetchPage(cursor: String?, limit: Int): FeedPage

    suspend fun setLike(postId: String, isLiked: Boolean): LikeUpdate
}
