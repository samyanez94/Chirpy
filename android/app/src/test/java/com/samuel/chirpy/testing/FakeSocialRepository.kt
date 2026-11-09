package com.samuel.chirpy.testing

import com.samuel.chirpy.core.data.CurrentProfileState
import com.samuel.chirpy.core.data.PostChange
import com.samuel.chirpy.core.data.SocialRepository
import com.samuel.chirpy.core.model.FeedPage
import com.samuel.chirpy.core.model.LikeUpdate
import com.samuel.chirpy.core.model.Post
import com.samuel.chirpy.core.model.Profile
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import java.time.Instant

internal class FakeSocialRepository : SocialRepository {
    override val currentProfileState = MutableStateFlow(CurrentProfileState())
    override val pendingPostIds = MutableStateFlow<Set<String>>(emptySet())
    override val changes = MutableSharedFlow<PostChange>(extraBufferCapacity = 16)
    val profile = Profile("me", "bird", "Bird", null)
    var page: suspend (String?) -> FeedPage = { FeedPage(emptyList(), null) }
    var search: suspend (String, String?) -> FeedPage = { _, _ -> FeedPage(emptyList(), null) }
    var create: suspend (String) -> Post = { post("created").copy(text = it) }
    var delete: suspend (String) -> Unit = {}
    var like: suspend (String, Boolean) -> LikeUpdate = { id, liked -> LikeUpdate(id, liked, 1) }
    val profileRequests = mutableListOf<Pair<String, String?>>()
    val searchRequests = mutableListOf<Pair<String, String?>>()

    override suspend fun fetchPage(cursor: String?, limit: Int): FeedPage = page(cursor)

    override suspend fun searchPosts(query: String, cursor: String?, limit: Int): FeedPage {
        searchRequests.add(query to cursor)
        return search(query, cursor)
    }

    override suspend fun profilePosts(profileId: String, cursor: String?, limit: Int): FeedPage {
        profileRequests.add(profileId to cursor)
        return page(cursor)
    }

    override suspend fun currentProfile(refresh: Boolean): Profile = profile.also {
        currentProfileState.value = CurrentProfileState(profile = it)
    }

    override suspend fun createPost(text: String): Post = create(text).also {
        changes.emit(PostChange.Created)
    }

    override suspend fun deletePost(postId: String) {
        delete(postId)
        changes.emit(PostChange.Deleted(postId))
    }

    override suspend fun setLike(postId: String, isLiked: Boolean): LikeUpdate =
        like(postId, isLiked).also {
            changes.emit(PostChange.Liked(it))
        }

    fun post(id: String): Post = Post(id, profile, "Hello flock", null, Instant.EPOCH, false, 0)
}
