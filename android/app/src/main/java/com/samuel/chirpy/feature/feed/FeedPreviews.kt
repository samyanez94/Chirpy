package com.samuel.chirpy.feature.feed

import android.content.res.Configuration
import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview
import com.samuel.chirpy.core.model.Post
import com.samuel.chirpy.core.model.Profile
import com.samuel.chirpy.core.ui.ChirpyTheme
import com.samuel.chirpy.feature.postlist.PostList
import com.samuel.chirpy.feature.postlist.PostListMessage
import com.samuel.chirpy.feature.postlist.PostListUiState
import java.time.Instant

@Preview(name = "Home")
@Preview(name = "Home dark", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Preview(name = "Home large text", fontScale = 2f)
@Composable
private fun HomePreview() {
    val post =
        Post(
            id = "preview",
            author = Profile("pip", "crumbclub", "Pip Sparrow", null),
            text = "Found a bagel. Calling off all meetings for the rest of the morning.",
            imageUrl = null,
            createdAt = Instant.parse("2026-11-04T12:00:00Z"),
            isLiked = true,
            likeCount = 12,
        )
    ChirpyTheme {
        PostList(
            state = PostListUiState(posts = listOf(post), isLoading = false),
            onRefresh = {},
            onLoadMore = {},
            onLike = {},
            onMessageDismissed = {},
        )
    }
}

@Preview(name = "Home error")
@Composable
private fun ErrorPreview() {
    ChirpyTheme {
        PostList(
            state = PostListUiState(isLoading = false, initialError = PostListMessage.LoadFailed),
            onRefresh = {},
            onLoadMore = {},
            onLike = {},
            onMessageDismissed = {},
        )
    }
}
