package com.samuel.chirpy.core.data

import com.samuel.chirpy.core.model.FeedPage
import com.samuel.chirpy.core.model.Post
import com.samuel.chirpy.core.model.Profile
import kotlinx.coroutines.flow.StateFlow

interface SocialRepository : FeedRepository {
    val currentProfileState: StateFlow<CurrentProfileState>

    // Includes active and queued mutations so all screens can disable conflicting actions.
    val pendingPostIds: StateFlow<Set<String>>
    suspend fun searchPosts(query: String, cursor: String?, limit: Int): FeedPage
    suspend fun profilePosts(profileId: String, cursor: String?, limit: Int): FeedPage
    suspend fun currentProfile(refresh: Boolean = false): Profile
    suspend fun createPost(text: String): Post
    suspend fun deletePost(postId: String)
}
