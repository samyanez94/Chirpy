package com.samuel.chirpy.feature.feed

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle

@Composable
fun FeedRoute(viewModel: FeedViewModel) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    FeedScreen(
        state,
        viewModel::refresh,
        viewModel::loadMore,
        viewModel::toggleLike,
        viewModel::dismissMessage,
    )
}
