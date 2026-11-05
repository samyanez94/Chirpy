package com.samuel.chirpy.core.data

import com.samuel.chirpy.core.model.FeedPage
import com.samuel.chirpy.core.model.LikeUpdate
import kotlinx.coroutines.flow.Flow

interface FeedRepository {
    // Successful mutations publish their authoritative results in completion order.
    val changes: Flow<PostChange>

    suspend fun fetchPage(cursor: String?, limit: Int): FeedPage

    suspend fun setLike(postId: String, isLiked: Boolean): LikeUpdate
}
