package com.samuel.chirpy.app

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Icon
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
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import androidx.navigation3.runtime.entryProvider
import androidx.navigation3.runtime.rememberSaveableStateHolderNavEntryDecorator
import androidx.navigation3.ui.NavDisplay
import com.samuel.chirpy.R
import com.samuel.chirpy.core.data.SocialRepository
import com.samuel.chirpy.feature.feed.FeedMode
import com.samuel.chirpy.feature.feed.FeedViewModel
import com.samuel.chirpy.feature.feed.Timeline
import com.samuel.chirpy.feature.postcomposer.PostComposerScreen
import com.samuel.chirpy.feature.postcomposer.PostComposerViewModel
import com.samuel.chirpy.feature.postdetail.PostDetailScreen
import com.samuel.chirpy.feature.postdetail.PostDetailViewModel
import com.samuel.chirpy.feature.profile.ProfileScreen
import com.samuel.chirpy.feature.search.SearchScreen

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChirpyAppRoot(repository: SocialRepository) {
    val social: SocialViewModel = viewModel(
        factory = viewModelFactory {
            initializer { SocialViewModel(repository) }
        },
    )
    val state by social.state.collectAsStateWithLifecycle()
    val composer: PostComposerViewModel = viewModel(
        factory = viewModelFactory { initializer { PostComposerViewModel(repository) } },
    )
    val composerState by composer.state.collectAsStateWithLifecycle()
    val detail: PostDetailViewModel = viewModel(
        factory = viewModelFactory { initializer { PostDetailViewModel(repository) } },
    )
    val detailState by detail.state.collectAsStateWithLifecycle()
    val close: () -> Unit = {
        if (!composer.state.value.isPosting && !detail.state.value.isBusy) {
            detail.close()
            social.close()
        }
    }
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
            onPost = { post ->
                if (social.state.value.destination == AppDestination.Timeline) {
                    detail.open(post)
                    social.open(AppDestination.Detail(post.id))
                }
            },
        )
    }
    BackHandler(state.destination == AppDestination.Timeline && tab != FeedMode.Home) {
        tab = FeedMode.Home
    }
    NavDisplay(
        backStack = state.backStack,
        onBack = close,
        entryDecorators = listOf(rememberSaveableStateHolderNavEntryDecorator()),
        entryProvider = entryProvider {
            entry<AppDestination.Composer> {
                PostComposerScreen(
                    composerState,
                    composer::editDraft,
                    { composer.publish(social::close) },
                    close,
                )
            }
            entry<AppDestination.Detail> { destination ->
                if (detailState.post?.id == destination.postId) {
                    PostDetailScreen(
                        detailState,
                        state.profile,
                        detail::toggleLike,
                        detail::delete,
                        close,
                        { social.loadProfile(refresh = true) },
                    )
                }
            }
            entry<AppDestination.Timeline> {
                Scaffold(
                    topBar = {
                        TopAppBar(title = { Text(stringResource(tab.titleResource())) })
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
                        ExtendedFloatingActionButton(
                            onClick = {
                                composer.open()
                                social.open(AppDestination.Composer)
                            },
                            icon = {
                                Icon(
                                    painterResource(R.drawable.ic_edit),
                                    contentDescription = stringResource(R.string.new_post),
                                )
                            },
                            text = { Text(stringResource(R.string.new_post)) },
                        )
                    },
                ) { padding ->
                    Column(
                        Modifier.fillMaxSize().padding(padding).consumeWindowInsets(padding),
                    ) {
                        savedTabs.SaveableStateProvider(tab.name) {
                            when (tab) {
                                FeedMode.Home -> timeline()

                                FeedMode.Search -> SearchScreen(searchText, {
                                    searchText = it
                                }, timeline)

                                FeedMode.Profile -> ProfileScreen(
                                    state.profile,
                                    refresh,
                                    timeline,
                                )
                            }
                        }
                    }
                }
            }
        },
    )
    // Consume Back while a mutation is active, including before a predictive pop starts.
    BackHandler(
        state.destination != AppDestination.Timeline &&
            (composerState.isPosting || detailState.isBusy),
    ) {}
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
