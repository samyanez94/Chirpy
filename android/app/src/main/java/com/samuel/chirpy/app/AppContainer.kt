package com.samuel.chirpy.app

import com.samuel.chirpy.BuildConfig
import com.samuel.chirpy.core.data.FeedRepository
import com.samuel.chirpy.core.network.NetworkFeedRepository

class AppContainer {
    val feedRepository: FeedRepository =
        NetworkFeedRepository.create(BuildConfig.API_BASE_URL, BuildConfig.API_KEY)
}
