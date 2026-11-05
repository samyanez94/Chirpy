package com.samuel.chirpy.feature.feed

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.samuel.chirpy.core.data.ApiException
import com.samuel.chirpy.core.data.MissingApiKeyException
import com.samuel.chirpy.core.data.PostChange
import com.samuel.chirpy.core.data.SocialRepository
import com.samuel.chirpy.core.model.FeedPage
import com.samuel.chirpy.core.model.LikeUpdate
import com.samuel.chirpy.core.model.Post
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class FeedViewModel(
    private val repository: SocialRepository,
    private val mode: FeedMode = FeedMode.Home,
) : ViewModel() {
    private var query = ""
    private val removedIds = mutableSetOf<String>()
    private val localPendingLikes = mutableSetOf<String>()

    private val mutableState = MutableStateFlow(FeedUiState())
    val state = mutableState.asStateFlow()

    private var pageJob: Job? = null
    private var generation = 0
    private var mutationVersion = 0L
    private val likeVersions = mutableMapOf<String, Long>()
    private val likeUpdates = mutableMapOf<String, LikeUpdate>()

    init {
        viewModelScope.launch {
            repository.pendingPostIds.collect { pending ->
                mutableState.update { it.copy(pendingLikes = pending + localPendingLikes) }
            }
        }
        viewModelScope.launch {
            repository.changes.collect { change ->
                when (change) {
                    is PostChange.Liked -> applyLike(change.update)

                    is PostChange.Deleted -> {
                        removedIds.add(change.id)
                        mutableState.update {
                            it.copy(
                                posts = it.posts.filterNot { post ->
                                    post.id == change.id
                                },
                            )
                        }
                    }

                    PostChange.Created -> refresh()
                }
            }
        }
        if (mode != FeedMode.Search) {
            refresh()
        } else {
            mutableState.update { it.copy(isLoading = false) }
        }
    }

    fun search(text: String) {
        val normalized = text.trim()
        if (normalized == query) return
        query = normalized
        ++generation
        pageJob?.cancel()
        mutableState.value =
            FeedUiState(
                isLoading = normalized.isNotEmpty(),
                pendingLikes = state.value.pendingLikes,
            )
        if (normalized.isNotEmpty()) {
            pageJob = viewModelScope.launch {
                delay(300)
                refresh()
            }
        }
    }

    private suspend fun fetchPage(cursor: String?): FeedPage = when (mode) {
        FeedMode.Home -> repository.fetchPage(cursor, PAGE_SIZE)

        FeedMode.Search -> repository.searchPosts(query, cursor, PAGE_SIZE)

        FeedMode.Profile -> repository.profilePosts(
            repository.currentProfile().id,
            cursor,
            PAGE_SIZE,
        )
    }

    private fun applyLike(update: LikeUpdate) {
        likeVersions[update.postId] = ++mutationVersion
        likeUpdates[update.postId] = update
        mutableState.update { current ->
            current.copy(
                posts = current.posts.map { post ->
                    if (post.id == update.postId) {
                        post.copy(isLiked = update.isLiked, likeCount = update.likeCount)
                    } else {
                        post
                    }
                },
            )
        }
    }

    fun refresh() {
        if (mode == FeedMode.Search && query.isEmpty()) return
        val requestGeneration = ++generation
        val startingMutationVersion = mutationVersion
        pageJob?.cancel()
        mutableState.update {
            it.copy(
                isLoading = it.posts.isEmpty(),
                isRefreshing = it.posts.isNotEmpty(),
                isLoadingMore = false,
                initialError = null,
                paginationFailed = false,
            )
        }
        pageJob = viewModelScope.launch {
            try {
                val page = fetchPage(null)
                if (generation != requestGeneration) return@launch
                mutableState.update { current ->
                    val posts = reconcile(page.posts, startingMutationVersion)
                    current.copy(
                        posts = posts,
                        nextCursor = page.nextCursor,
                        isLoading = false,
                        isRefreshing = false,
                    )
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                if (generation != requestGeneration) return@launch
                mutableState.update {
                    it.copy(
                        isLoading = false,
                        isRefreshing = false,
                        initialError =
                        if (it.posts.isEmpty()) {
                            if (error is MissingApiKeyException) {
                                FeedMessage.MissingConfiguration
                            } else {
                                FeedMessage.LoadFailed
                            }
                        } else {
                            null
                        },
                        message = if (it.posts.isNotEmpty()) FeedMessage.RefreshFailed else null,
                    )
                }
            }
        }
    }

    fun loadMore() {
        val current = state.value
        val cursor = current.nextCursor ?: return
        if (
            current.isLoading ||
            current.isRefreshing ||
            current.isLoadingMore ||
            current.initialError != null
        ) {
            return
        }
        val requestGeneration = generation
        val startingMutationVersion = mutationVersion
        mutableState.update { it.copy(isLoadingMore = true, paginationFailed = false) }
        pageJob = viewModelScope.launch {
            try {
                val page = fetchPage(cursor)
                if (generation != requestGeneration) return@launch
                mutableState.update {
                    val known = it.posts.map { post -> post.id }.toMutableSet()
                    it.copy(
                        posts =
                        it.posts +
                            reconcile(page.posts, startingMutationVersion).filter { post ->
                                known.add(post.id)
                            },
                        nextCursor = page.nextCursor.takeUnless { next -> next == cursor },
                        isLoadingMore = false,
                    )
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                if (generation != requestGeneration) return@launch
                if (error is ApiException && error.code == "invalid_cursor") {
                    refresh()
                } else {
                    mutableState.update { it.copy(isLoadingMore = false, paginationFailed = true) }
                }
            }
        }
    }

    fun toggleLike(postId: String) {
        val current = state.value
        val post = current.posts.firstOrNull { it.id == postId } ?: return
        if (postId in current.pendingLikes || postId in repository.pendingPostIds.value) return
        localPendingLikes.add(postId)
        mutableState.update { it.copy(pendingLikes = it.pendingLikes + postId) }
        viewModelScope.launch {
            try {
                repository.setLike(postId, !post.isLiked)
            } catch (error: CancellationException) {
                throw error
            } catch (_: Exception) {
                mutableState.update { it.copy(message = FeedMessage.LikeFailed) }
            } finally {
                localPendingLikes.remove(postId)
                mutableState.update {
                    it.copy(pendingLikes = repository.pendingPostIds.value + localPendingLikes)
                }
            }
        }
    }

    private fun reconcile(posts: List<Post>, startingVersion: Long): List<Post> = posts
        .filterNot { it.id in removedIds }
        .distinctBy { it.id }
        .map { post ->
            val update = likeUpdates[post.id]
            if (update != null && (likeVersions[post.id] ?: 0) > startingVersion) {
                post.copy(isLiked = update.isLiked, likeCount = update.likeCount)
            } else {
                post
            }
        }

    fun dismissMessage() {
        mutableState.update { it.copy(message = null) }
    }

    companion object {
        private const val PAGE_SIZE = 20
    }
}
