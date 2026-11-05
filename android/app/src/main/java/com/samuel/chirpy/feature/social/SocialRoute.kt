package com.samuel.chirpy.feature.social

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.samuel.chirpy.R
import com.samuel.chirpy.core.data.SocialRepository
import com.samuel.chirpy.feature.feed.FeedMode
import com.samuel.chirpy.feature.feed.FeedViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SocialRoute(repository: SocialRepository) {
    val social: SocialViewModel = viewModel(
        factory = viewModelFactory {
            initializer { SocialViewModel(repository) }
        },
    )
    val state by social.state.collectAsStateWithLifecycle()
    var tab by rememberSaveable { mutableStateOf(FeedMode.Home) }
    val home: FeedViewModel = feedModel(repository, FeedMode.Home)
    val search: FeedViewModel = feedModel(repository, FeedMode.Search)
    val profile: FeedViewModel = feedModel(repository, FeedMode.Profile)
    val savedTabs = rememberSaveableStateHolder()
    var searchText by rememberSaveable { mutableStateOf("") }
    LaunchedEffect(searchText) { search.search(searchText) }
    val activeFeed = when (tab) {
        FeedMode.Home -> home
        FeedMode.Search -> search
        FeedMode.Profile -> profile
    }
    val feedState by key(tab) { activeFeed.state.collectAsStateWithLifecycle() }
    val refresh: () -> Unit = {
        if (tab == FeedMode.Profile) social.loadProfile(refresh = true)
        activeFeed.refresh()
    }
    val timeline: @Composable () -> Unit = {
        Timeline(
            state = feedState,
            onRefresh = refresh,
            onLoadMore = activeFeed::loadMore,
            onLike = activeFeed::toggleLike,
            onMessageDismissed = activeFeed::dismissMessage,
            onPost = social::openPost,
        )
    }
    BackHandler(state.destination != SocialDestination.Timeline || tab != FeedMode.Home) {
        if (state.destination != SocialDestination.Timeline) social.close() else tab = FeedMode.Home
    }
    when (val destination = state.destination) {
        SocialDestination.Composer -> ComposerScreen(
            state.composer,
            social::editDraft,
            social::publish,
            social::close,
        )

        is SocialDestination.Detail -> DetailScreen(
            destination.post,
            state.detail,
            state.profile,
            social::toggleLike,
            social::delete,
            social::close,
            { social.loadProfile(refresh = true) },
        )

        SocialDestination.Timeline -> Scaffold(
            topBar = {
                TopAppBar(title = { Text(stringResource(tab.titleResource())) }, actions = {
                    IconButton(
                        onClick = refresh,
                        enabled =
                        !feedState.isLoading && !feedState.isRefreshing,
                    ) {
                        Icon(
                            painterResource(R.drawable.ic_refresh),
                            stringResource(R.string.refresh),
                        )
                    }
                })
            },
            bottomBar = {
                NavigationBar {
                    FeedMode.entries.forEach { mode ->
                        val label = stringResource(mode.titleResource())
                        NavigationBarItem(
                            selected = tab == mode,
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = MaterialTheme.colorScheme.primary,
                                selectedTextColor = MaterialTheme.colorScheme.primary,
                            ),
                            onClick = { tab = mode },
                            icon = { Icon(painterResource(mode.iconResource()), null) },
                            label = { Text(label) },
                        )
                    }
                }
            },
            floatingActionButton = {
                FloatingActionButton(onClick = social::compose) {
                    Text(stringResource(R.string.new_post), Modifier.padding(horizontal = 16.dp))
                }
            },
        ) { padding ->
            Column(Modifier.fillMaxSize().padding(padding).consumeWindowInsets(padding)) {
                savedTabs.SaveableStateProvider(tab.name) {
                    when (tab) {
                        FeedMode.Home -> timeline()
                        FeedMode.Search -> SearchScreen(searchText, { searchText = it }, timeline)
                        FeedMode.Profile -> ProfileScreen(state.profile, refresh, timeline)
                    }
                }
            }
        }
    }
}

@Composable
private fun feedModel(repository: SocialRepository, mode: FeedMode): FeedViewModel = viewModel(
    key = mode.name,
    factory = viewModelFactory { initializer { FeedViewModel(repository, mode) } },
)

private fun FeedMode.titleResource(): Int = when (this) {
    FeedMode.Home -> R.string.home
    FeedMode.Search -> R.string.search
    FeedMode.Profile -> R.string.profile
}

private fun FeedMode.iconResource(): Int = when (this) {
    FeedMode.Home -> R.drawable.ic_home
    FeedMode.Search -> R.drawable.ic_search
    FeedMode.Profile -> R.drawable.ic_profile
}
