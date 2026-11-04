package com.samuel.chirpy.feature.feed

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.samuel.chirpy.core.data.ApiException
import com.samuel.chirpy.core.data.FeedRepository
import com.samuel.chirpy.core.data.MissingApiKeyException
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class FeedViewModel(private val repository: FeedRepository) : ViewModel() {
    private val mutableState = MutableStateFlow(FeedUiState())
    val state = mutableState.asStateFlow()

    private var pageJob: Job? = null
    private var generation = 0
    private var mutationVersion = 0L
    private val likeVersions = mutableMapOf<String, Long>()

    init {
        refresh()
    }

    fun refresh() {
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
                val page = repository.fetchPage(null, PAGE_SIZE)
                if (generation != requestGeneration) return@launch
                mutableState.update { current ->
                    val existing = current.posts.associateBy { it.id }
                    val posts =
                        page.posts
                            .distinctBy { it.id }
                            .map { post ->
                                val latest = existing[post.id]
                                if (
                                    latest != null &&
                                    (likeVersions[post.id] ?: 0) > startingMutationVersion
                                ) {
                                    post.copy(
                                        isLiked = latest.isLiked,
                                        likeCount = latest.likeCount,
                                    )
                                } else {
                                    post
                                }
                            }
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
        mutableState.update { it.copy(isLoadingMore = true, paginationFailed = false) }
        pageJob = viewModelScope.launch {
            try {
                val page = repository.fetchPage(cursor, PAGE_SIZE)
                if (generation != requestGeneration) return@launch
                mutableState.update {
                    val known = it.posts.map { post -> post.id }.toMutableSet()
                    it.copy(
                        posts = it.posts + page.posts.filter { post -> known.add(post.id) },
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
        if (postId in current.pendingLikes) return
        mutableState.update { it.copy(pendingLikes = it.pendingLikes + postId) }
        viewModelScope.launch {
            try {
                val result = repository.setLike(postId, !post.isLiked)
                likeVersions[postId] = ++mutationVersion
                mutableState.update {
                    it.copy(
                        posts =
                        it.posts.map { item ->
                            if (item.id == postId) {
                                item.copy(
                                    isLiked = result.isLiked,
                                    likeCount = result.likeCount,
                                )
                            } else {
                                item
                            }
                        },
                    )
                }
            } catch (error: CancellationException) {
                throw error
            } catch (_: Exception) {
                mutableState.update { it.copy(message = FeedMessage.LikeFailed) }
            } finally {
                mutableState.update { it.copy(pendingLikes = it.pendingLikes - postId) }
            }
        }
    }

    fun dismissMessage() {
        mutableState.update { it.copy(message = null) }
    }

    companion object {
        private const val PAGE_SIZE = 20
    }
}
