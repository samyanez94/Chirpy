package com.samuel.chirpy.app

import androidx.annotation.DrawableRes
import androidx.annotation.StringRes
import com.samuel.chirpy.R
import com.samuel.chirpy.feature.postlist.PostListSource

internal enum class AppTab(
    @StringRes val titleResource: Int,
    @DrawableRes val iconResource: Int,
    val source: PostListSource,
) {
    Home(R.string.home, R.drawable.ic_home, PostListSource.HomeFeed),
    Search(R.string.search, R.drawable.ic_search, PostListSource.SearchResults),
    Profile(R.string.profile, R.drawable.ic_profile, PostListSource.ProfilePosts),
}
