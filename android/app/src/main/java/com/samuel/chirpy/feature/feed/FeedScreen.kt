package com.samuel.chirpy.feature.feed

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.ScaffoldDefaults
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.pulltorefresh.PullToRefreshDefaults
import androidx.compose.material3.pulltorefresh.rememberPullToRefreshState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import com.samuel.chirpy.R
import com.samuel.chirpy.core.ui.PostRow
import com.samuel.chirpy.core.ui.rememberRelativePostDateFormatter
import kotlinx.coroutines.flow.distinctUntilChanged

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FeedScreen(
    state: FeedUiState,
    onRefresh: () -> Unit,
    onLoadMore: () -> Unit,
    onLike: (String) -> Unit,
    onMessageDismissed: (Long) -> Unit,
    title: String = stringResource(R.string.home),
    onPost: (com.samuel.chirpy.core.model.Post) -> Unit = {},
    showToolbar: Boolean = true,
    emptyMessage: String = stringResource(R.string.empty_message),
) {
    val formatDate = rememberRelativePostDateFormatter()
    val currentOnMessageDismissed by rememberUpdatedState(onMessageDismissed)
    val listState = rememberLazyListState()
    val pullToRefreshState = rememberPullToRefreshState()
    val snackbar = remember { SnackbarHostState() }
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    val message = state.message
    val messageText = message?.let { stringResource(it.kind.resourceId()) }
    LaunchedEffect(message?.id, messageText, lifecycle) {
        if (message != null && messageText != null) {
            // Keep pending errors until they can be shown while the feed is visible.
            lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
                snackbar.showSnackbar(messageText)
                currentOnMessageDismissed(message.id)
            }
        }
    }
    FeedPaginationEffect(state, listState, onLoadMore)
    Scaffold(
        contentWindowInsets = if (showToolbar) {
            ScaffoldDefaults.contentWindowInsets
        } else {
            WindowInsets(
                0,
            )
        },
        topBar = {
            if (showToolbar) {
                TopAppBar(title = { Text(title) })
            }
        },
        snackbarHost = { SnackbarHost(snackbar) },
    ) { padding ->
        PullToRefreshBox(
            isRefreshing = state.isRefreshing,
            onRefresh = onRefresh,
            modifier = Modifier.fillMaxSize().consumeWindowInsets(padding),
            state = pullToRefreshState,
            indicator = {
                PullToRefreshDefaults.Indicator(
                    state = pullToRefreshState,
                    isRefreshing = state.isRefreshing,
                    modifier =
                    Modifier.align(Alignment.TopCenter)
                        .padding(top = padding.calculateTopPadding()),
                )
            },
        ) {
            when {
                state.isLoading -> LoadingState(Modifier.padding(padding))

                state.initialError != null ->
                    FeedStatus(
                        stringResource(state.initialError.resourceId()),
                        null,
                        onRefresh,
                        Modifier.fillMaxSize()
                            .padding(padding)
                            .verticalScroll(rememberScrollState()),
                    )

                state.posts.isEmpty() && state.nextCursor == null ->
                    FeedStatus(
                        stringResource(R.string.empty_title),
                        emptyMessage,
                        onRefresh,
                        Modifier.fillMaxSize()
                            .padding(padding)
                            .verticalScroll(rememberScrollState()),
                    )

                else ->
                    LazyColumn(
                        state = listState,
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = padding,
                    ) {
                        items(state.posts, key = { it.id }, contentType = { "post" }) { post ->
                            PostRow(
                                post,
                                post.id in state.pendingLikes,
                                { onLike(post.id) },
                                formatDate,
                                Modifier.clickable { onPost(post) },
                            )
                            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                        }
                        if (state.paginationFailed) {
                            item(key = "pagination_error", contentType = "error") {
                                FeedStatus(
                                    stringResource(R.string.pagination_error),
                                    null,
                                    onLoadMore,
                                )
                            }
                        }
                        if (state.isLoadingMore) {
                            item(key = "pagination_progress", contentType = "progress") {
                                Column(
                                    Modifier.fillMaxWidth().padding(24.dp),
                                    horizontalAlignment = Alignment.CenterHorizontally,
                                ) {
                                    CircularProgressIndicator()
                                    Text(stringResource(R.string.loading_more))
                                }
                            }
                        }
                    }
            }
            // Keep gesture-navigation icons legible as artwork scrolls behind them.
            Spacer(
                Modifier.align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .height(padding.calculateBottomPadding())
                    .background(
                        Brush.verticalGradient(
                            listOf(
                                Color.Transparent,
                                MaterialTheme.colorScheme.surface,
                            ),
                        ),
                    ),
            )
        }
    }
}

@Composable
private fun FeedPaginationEffect(
    state: FeedUiState,
    listState: LazyListState,
    onLoadMore: () -> Unit,
) {
    val currentOnLoadMore by rememberUpdatedState(onLoadMore)
    // Cursor changes restart observation, including pages containing only duplicate posts.
    LaunchedEffect(
        state.nextCursor,
        state.isLoading,
        state.initialError,
        state.isLoadingMore,
        state.isRefreshing,
        state.paginationFailed,
    ) {
        if (
            state.nextCursor != null &&
            !state.isLoading &&
            state.initialError == null &&
            !state.isLoadingMore &&
            !state.isRefreshing &&
            !state.paginationFailed
        ) {
            snapshotFlow {
                val last = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: -1
                state.posts.isEmpty() || last >= state.posts.size - 5
            }
                .distinctUntilChanged()
                .collect { nearEnd -> if (nearEnd) currentOnLoadMore() }
        }
    }
}

@Composable
private fun LoadingState(modifier: Modifier = Modifier) {
    Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            CircularProgressIndicator()
            Text(stringResource(R.string.loading_feed))
        }
    }
}

@Composable
private fun FeedStatus(
    title: String,
    description: String?,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier.fillMaxWidth().padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(title, style = MaterialTheme.typography.titleMedium)
        description?.let { Text(it, style = MaterialTheme.typography.bodyMedium) }
        Button(
            onClick = onRetry,
            colors = ButtonDefaults.buttonColors(contentColor = Color.White),
        ) { Text(stringResource(R.string.retry)) }
    }
}

private fun FeedMessage.resourceId(): Int = when (this) {
    FeedMessage.LoadFailed -> R.string.feed_error
    FeedMessage.RefreshFailed -> R.string.refresh_error
    FeedMessage.LikeFailed -> R.string.like_error
    FeedMessage.MissingConfiguration -> R.string.configuration_error
}
