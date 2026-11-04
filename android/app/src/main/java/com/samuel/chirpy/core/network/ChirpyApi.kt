package com.samuel.chirpy.core.network

import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path
import retrofit2.http.Query

internal interface ChirpyApi {
    @GET("functions/v1/feed")
    suspend fun feed(@Query("cursor") cursor: String?, @Query("limit") limit: Int): FeedPageDto

    @POST("functions/v1/posts/{id}/like")
    suspend fun like(@Path("id") postId: String): LikeUpdateDto

    @DELETE("functions/v1/posts/{id}/like")
    suspend fun unlike(@Path("id") postId: String): LikeUpdateDto
}
