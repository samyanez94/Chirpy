package com.samuel.chirpy.app

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

internal class NavigationTestRepository(
    private val beforePublish: suspend () -> Unit = {},
    private val beforeLike: suspend () -> Unit = {},
) : SocialRepository {
    private val profile = Profile("me", "bird", "Bird", null)
    private val post = Post("post", profile, "Hello flock", null, Instant.EPOCH, false, 0)
    override val currentProfileState = MutableStateFlow(CurrentProfileState(profile = profile))
    override val pendingPostIds = MutableStateFlow<Set<String>>(emptySet())
    override val changes = MutableSharedFlow<PostChange>(extraBufferCapacity = 16)

    override suspend fun fetchPage(cursor: String?, limit: Int) = FeedPage(listOf(post), null)

    override suspend fun searchPosts(query: String, cursor: String?, limit: Int) =
        fetchPage(cursor, limit)

    override suspend fun profilePosts(profileId: String, cursor: String?, limit: Int) =
        fetchPage(cursor, limit)

    override suspend fun currentProfile(refresh: Boolean) = profile

    override suspend fun createPost(text: String): Post {
        beforePublish()
        val created = post.copy(id = "new", text = text)
        changes.emit(PostChange.Created)
        return created
    }

    override suspend fun deletePost(postId: String) {
        changes.emit(PostChange.Deleted(postId))
    }

    override suspend fun setLike(postId: String, isLiked: Boolean): LikeUpdate {
        beforeLike()
        return LikeUpdate(postId, isLiked, if (isLiked) 1 else 0).also {
            changes.emit(PostChange.Liked(it))
        }
    }
}
