package com.samuel.chirpy.core.network

import com.samuel.chirpy.core.data.ApiException
import com.samuel.chirpy.core.data.FeedRepository
import com.samuel.chirpy.core.data.MissingApiKeyException
import com.samuel.chirpy.core.model.FeedPage
import com.samuel.chirpy.core.model.LikeUpdate
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
) : FeedRepository {
    override suspend fun fetchPage(cursor: String?, limit: Int): FeedPage = request {
        val page = api.feed(cursor, limit)
        FeedPage(page.posts.map { it.toModel() }, page.nextCursor)
    }

    override suspend fun setLike(postId: String, isLiked: Boolean): LikeUpdate = request {
        val update = if (isLiked) api.like(postId) else api.unlike(postId)
        LikeUpdate(update.postID, update.isLiked, update.likeCount)
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
        fun create(baseUrl: String, apiKey: String): FeedRepository {
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
