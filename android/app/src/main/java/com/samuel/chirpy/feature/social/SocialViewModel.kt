package com.samuel.chirpy.feature.social

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.samuel.chirpy.core.data.PostChange
import com.samuel.chirpy.core.data.SocialRepository
import com.samuel.chirpy.core.model.Post
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class SocialViewModel(private val repository: SocialRepository) : ViewModel() {
    private val mutableState = MutableStateFlow(SocialUiState())
    val state = mutableState.asStateFlow()

    init {
        viewModelScope.launch {
            repository.currentProfileState.collect { profile ->
                mutableState.update { it.copy(profile = profile) }
            }
        }
        viewModelScope.launch {
            repository.pendingPostIds.collect { pending ->
                mutableState.update {
                    val post = it.selectedPost.takeIf { _ ->
                        it.destination is SocialDestination.Detail
                    }
                    it.copy(detail = it.detail.copy(isPending = post?.id in pending))
                }
            }
        }
        viewModelScope.launch {
            repository.changes.collect { change -> applyChange(change) }
        }
        loadProfile()
    }

    private fun applyChange(change: PostChange) {
        mutableState.update { current ->
            val post = current.selectedPost.takeIf {
                current.destination is SocialDestination.Detail
            }
            when {
                change is PostChange.Liked && post?.id == change.update.postId -> current.copy(
                    selectedPost = post.copy(
                        isLiked = change.update.isLiked,
                        likeCount = change.update.likeCount,
                    ),
                )

                change is PostChange.Deleted && post?.id == change.id -> current.copy(
                    backStack = listOf(SocialDestination.Timeline),
                    detail = DetailUiState(),
                )

                else -> current
            }
        }
    }

    fun loadProfile(refresh: Boolean = false) {
        if (repository.currentProfileState.value.isLoading) return
        viewModelScope.launch {
            try {
                repository.currentProfile(refresh)
            } catch (error: CancellationException) {
                throw error
            } catch (_: Exception) {
                // The repository publishes the failure alongside the last successful profile.
            }
        }
    }

    fun openPost(post: Post) {
        if (state.value.composer.isPosting || state.value.detail.isBusy) return
        mutableState.update {
            it.copy(
                backStack = listOf(SocialDestination.Timeline, SocialDestination.Detail(post.id)),
                selectedPost = post,
                detail = DetailUiState(isPending = post.id in repository.pendingPostIds.value),
            )
        }
    }

    fun compose() {
        if (state.value.destination != SocialDestination.Timeline) return
        mutableState.update {
            it.copy(
                backStack = listOf(SocialDestination.Timeline, SocialDestination.Composer),
                composer = it.composer.copy(hasFailed = false),
            )
        }
    }

    fun editDraft(text: String) {
        if (!state.value.composer.isPosting) {
            mutableState.update { it.copy(composer = it.composer.copy(draft = text)) }
        }
    }

    fun close() {
        if (state.value.composer.isPosting || state.value.detail.isBusy) return
        mutableState.update {
            it.copy(backStack = listOf(SocialDestination.Timeline), detail = DetailUiState())
        }
    }

    fun publish() {
        val composer = state.value.composer
        if (!composer.canPublish) return
        mutableState.update {
            it.copy(composer = composer.copy(isPosting = true, hasFailed = false))
        }
        viewModelScope.launch {
            try {
                repository.createPost(PostDraft.trimmed(composer.draft))
                mutableState.update {
                    it.copy(
                        backStack = listOf(SocialDestination.Timeline),
                        composer = ComposerUiState(),
                    )
                }
            } catch (error: CancellationException) {
                throw error
            } catch (_: Exception) {
                mutableState.update { it.copy(composer = it.composer.copy(hasFailed = true)) }
            } finally {
                mutableState.update { it.copy(composer = it.composer.copy(isPosting = false)) }
            }
        }
    }

    fun delete() {
        val current = state.value
        if (current.destination !is SocialDestination.Detail) return
        val post = current.selectedPost ?: return
        if (current.detail.isBusy || post.id in repository.pendingPostIds.value ||
            repository.currentProfileState.value.profile?.id != post.author.id
        ) {
            return
        }
        mutableState.update {
            it.copy(detail = it.detail.copy(isDeleting = true, hasFailed = false))
        }
        viewModelScope.launch {
            try {
                repository.deletePost(post.id)
                applyChange(PostChange.Deleted(post.id))
            } catch (error: CancellationException) {
                throw error
            } catch (_: Exception) {
                mutableState.update { it.copy(detail = it.detail.copy(hasFailed = true)) }
            } finally {
                mutableState.update { it.copy(detail = it.detail.copy(isDeleting = false)) }
            }
        }
    }

    fun toggleLike() {
        val current = state.value
        if (current.destination !is SocialDestination.Detail) return
        val post = current.selectedPost ?: return
        if (current.detail.isBusy || post.id in repository.pendingPostIds.value) return
        mutableState.update { it.copy(detail = it.detail.copy(isLiking = true, hasFailed = false)) }
        viewModelScope.launch {
            try {
                repository.setLike(post.id, !post.isLiked)
            } catch (error: CancellationException) {
                throw error
            } catch (_: Exception) {
                mutableState.update { it.copy(detail = it.detail.copy(hasFailed = true)) }
            } finally {
                mutableState.update { it.copy(detail = it.detail.copy(isLiking = false)) }
            }
        }
    }
}
