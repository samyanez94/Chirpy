package com.samuel.chirpy.core.network

import com.samuel.chirpy.core.data.ApiException
import com.samuel.chirpy.core.data.CurrentProfileState
import com.samuel.chirpy.core.data.MissingApiKeyException
import com.samuel.chirpy.core.data.PostChange
import com.samuel.chirpy.core.data.PostMutationCoordinator
import com.samuel.chirpy.core.data.SocialRepository
import com.samuel.chirpy.core.model.FeedPage
import com.samuel.chirpy.core.model.LikeUpdate
import com.samuel.chirpy.core.model.Post
import com.samuel.chirpy.core.model.Profile
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import retrofit2.HttpException
import retrofit2.Retrofit
import retrofit2.converter.kotlinx.serialization.asConverterFactory

internal class NetworkFeedRepository(
    private val api: ChirpyApi,
    private val json: Json,
    private val hasApiKey: Boolean,
) : SocialRepository {
    private val mutableChanges = MutableSharedFlow<PostChange>(extraBufferCapacity = 64)
    override val changes = mutableChanges.asSharedFlow()

    private val profileMutex = Mutex()
    private val mutableProfile = MutableStateFlow(CurrentProfileState())
    override val currentProfileState = mutableProfile.asStateFlow()
    private val mutations = PostMutationCoordinator()
    override val pendingPostIds = mutations.pending

    override suspend fun currentProfile(refresh: Boolean): Profile {
        val observed = mutableProfile.value
        return profileMutex.withLock {
            val current = mutableProfile.value
            // Coalesce concurrent refreshes as well as initial loads.
            current.profile?.let {
                if (!refresh || current !== observed) return@withLock it
            }
            mutableProfile.value = current.copy(isLoading = true, hasFailed = false)
            try {
                request { api.profile().toModel() }.also {
                    mutableProfile.value = CurrentProfileState(profile = it)
                }
            } catch (error: CancellationException) {
                mutableProfile.value = current.copy(isLoading = false)
                throw error
            } catch (error: Exception) {
                mutableProfile.value = current.copy(isLoading = false, hasFailed = true)
                throw error
            }
        }
    }

    override suspend fun searchPosts(query: String, cursor: String?, limit: Int): FeedPage =
        request {
            val page = api.search(query, cursor, limit)
            FeedPage(page.posts.map { it.toModel() }, page.nextCursor)
        }

    override suspend fun profilePosts(profileId: String, cursor: String?, limit: Int): FeedPage =
        request {
            val page = api.profilePosts(profileId, cursor, limit)
            FeedPage(page.posts.map { it.toModel() }, page.nextCursor)
        }

    override suspend fun createPost(text: String): Post = request {
        api.create(CreatePostDto(text)).toModel().also { mutableChanges.emit(PostChange.Created) }
    }

    override suspend fun deletePost(postId: String) = mutations.mutate(postId) {
        try {
            request { api.delete(postId) }
        } catch (error: ApiException) {
            if (error.code != "post_not_found") throw error
        }
        mutableChanges.emit(PostChange.Deleted(postId))
    }

    override suspend fun fetchPage(cursor: String?, limit: Int): FeedPage = request {
        val page = api.feed(cursor, limit)
        FeedPage(page.posts.map { it.toModel() }, page.nextCursor)
    }

    override suspend fun setLike(postId: String, isLiked: Boolean): LikeUpdate =
        mutations.mutate(postId) {
            request {
                val update = if (isLiked) api.like(postId) else api.unlike(postId)
                LikeUpdate(update.postID, update.isLiked, update.likeCount).also {
                    mutableChanges.emit(PostChange.Liked(it))
                }
            }
        }

    private suspend fun <T> request(block: suspend () -> T): T {
        if (!hasApiKey) throw MissingApiKeyException()
        try {
            return block()
        } catch (error: HttpException) {
            val body = error.response()?.errorBody()?.string()
            val detail =
                try {
                    body?.let { json.decodeFromString<ApiErrorDto>(it).error }
                } catch (_: SerializationException) {
                    null
                }
            throw ApiException(detail?.code ?: "http_error", error.code(), detail?.requestID)
        }
    }

    companion object {
        fun create(baseUrl: String, apiKey: String): SocialRepository {
            val json = Json { ignoreUnknownKeys = true }
            // Image requests use Coil's separate client, so this header stays on API requests.
            val client =
                OkHttpClient.Builder()
                    .followRedirects(false)
                    .addInterceptor { chain ->
                        chain.proceed(
                            chain.request().newBuilder().header("X-Chirpy-API-Key", apiKey).build(),
                        )
                    }
                    .build()
            val api =
                Retrofit.Builder()
                    .baseUrl(baseUrl.trimEnd('/') + "/")
                    .client(client)
                    .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
                    .build()
                    .create(ChirpyApi::class.java)
            return NetworkFeedRepository(api, json, apiKey.isNotBlank())
        }
    }
}
