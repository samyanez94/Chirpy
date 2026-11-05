package com.samuel.chirpy.core.data

import com.samuel.chirpy.core.model.LikeUpdate

sealed interface PostChange {
    data class Liked(val update: LikeUpdate) : PostChange
    data class Deleted(val id: String) : PostChange
    data object Created : PostChange
}
