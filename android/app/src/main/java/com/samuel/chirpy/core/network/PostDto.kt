package com.samuel.chirpy.core.network

import com.samuel.chirpy.core.model.Post
import kotlinx.serialization.Serializable
import java.time.Instant

@Serializable
internal data class PostDto(
    val id: String,
    val author: ProfileDto,
    val text: String,
    val imageURL: String? = null,
    val createdAt: String,
    val isLiked: Boolean,
    val likeCount: Int,
) {
    fun toModel() =
        Post(id, author.toModel(), text, imageURL, Instant.parse(createdAt), isLiked, likeCount)
}
