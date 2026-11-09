package com.samuel.chirpy.app

import androidx.navigation3.runtime.NavKey

sealed interface AppDestination : NavKey {
    data object Timeline : AppDestination
    data object Composer : AppDestination
    data class Detail(val postId: String) : AppDestination
}
