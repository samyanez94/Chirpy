package com.samuel.chirpy.app

import com.samuel.chirpy.BuildConfig
import com.samuel.chirpy.core.data.SocialRepository
import com.samuel.chirpy.core.network.NetworkSocialRepository

class AppContainer {
    val socialRepository: SocialRepository =
        NetworkSocialRepository.create(BuildConfig.API_BASE_URL, BuildConfig.API_KEY)
}
