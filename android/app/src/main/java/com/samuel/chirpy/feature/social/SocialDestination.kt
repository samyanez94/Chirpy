package com.samuel.chirpy.feature.social

import com.samuel.chirpy.core.model.Post

sealed interface SocialDestination {
    data object Timeline : SocialDestination
    data object Composer : SocialDestination
    data class Detail(val post: Post) : SocialDestination
}
