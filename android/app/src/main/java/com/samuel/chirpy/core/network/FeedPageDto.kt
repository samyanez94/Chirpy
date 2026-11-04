package com.samuel.chirpy.core.network

import kotlinx.serialization.Serializable

@Serializable
internal data class FeedPageDto(val posts: List<PostDto>, val nextCursor: String? = null)
