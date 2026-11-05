package com.samuel.chirpy.feature.social

import androidx.navigation3.runtime.NavKey

sealed interface SocialDestination : NavKey {
    data object Timeline : SocialDestination
    data object Composer : SocialDestination
    data class Detail(val postId: String) : SocialDestination
}
