package com.samuel.chirpy.core.network

import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path
import retrofit2.http.Query

internal interface ChirpyApi {
    @GET("functions/v1/profile")
    suspend fun profile(): ProfileDto

    @GET("functions/v1/search")
    suspend fun search(
        @Query("q") query: String,
        @Query("cursor") cursor: String?,
        @Query("limit") limit: Int,
    ): FeedPageDto

    @GET("functions/v1/feed")
    suspend fun profilePosts(
        @Query("profile_id") profileId: String,
        @Query("cursor") cursor: String?,
        @Query("limit") limit: Int,
    ): FeedPageDto

    @POST("functions/v1/posts")
    suspend fun create(@Body body: CreatePostDto): PostDto

    @DELETE("functions/v1/posts/{id}")
    suspend fun delete(@Path("id") postId: String)

    @GET("functions/v1/feed")
    suspend fun feed(@Query("cursor") cursor: String?, @Query("limit") limit: Int): FeedPageDto

    @POST("functions/v1/posts/{id}/like")
    suspend fun like(@Path("id") postId: String): LikeUpdateDto

    @DELETE("functions/v1/posts/{id}/like")
    suspend fun unlike(@Path("id") postId: String): LikeUpdateDto
}
