package com.samuel.chirpy.feature.postdetail

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

class PostDetailViewModel(private val repository: SocialRepository) : ViewModel() {
    private val mutableState = MutableStateFlow(PostDetailUiState())
    val state = mutableState.asStateFlow()

    init {
        viewModelScope.launch {
            repository.pendingPostIds.collect { pending ->
                mutableState.update { it.copy(isPending = it.post?.id in pending) }
            }
        }
        viewModelScope.launch {
            repository.changes.collect(::applyChange)
        }
    }

    private fun applyChange(change: PostChange) {
        when (change) {
            is PostChange.Liked -> updatePost(change.update.postId) { current ->
                current.copy(
                    post = current.post?.copy(
                        isLiked = change.update.isLiked,
                        likeCount = change.update.likeCount,
                    ),
                )
            }

            is PostChange.Deleted -> updatePost(change.id) { PostDetailUiState() }

            PostChange.Created -> Unit
        }
    }

    fun open(post: Post) {
        mutableState.value =
            PostDetailUiState(post = post, isPending = post.id in repository.pendingPostIds.value)
    }

    fun close() {
        mutableState.value = PostDetailUiState()
    }

    fun delete() {
        val current = state.value
        val post = current.post ?: return
        if (current.isBusy || post.id in repository.pendingPostIds.value ||
            repository.currentProfileState.value.profile?.id != post.author.id
        ) {
            return
        }
        mutableState.update {
            it.copy(isDeleting = true, hasFailed = false)
        }
        viewModelScope.launch {
            try {
                repository.deletePost(post.id)
            } catch (error: CancellationException) {
                throw error
            } catch (_: Exception) {
                updatePost(post.id) { it.copy(hasFailed = true) }
            } finally {
                updatePost(post.id) { it.copy(isDeleting = false) }
            }
        }
    }

    fun toggleLike() {
        val current = state.value
        val post = current.post ?: return
        if (current.isBusy || post.id in repository.pendingPostIds.value) return
        mutableState.update { it.copy(isLiking = true, hasFailed = false) }
        viewModelScope.launch {
            try {
                repository.setLike(post.id, !post.isLiked)
            } catch (error: CancellationException) {
                throw error
            } catch (_: Exception) {
                updatePost(post.id) { it.copy(hasFailed = true) }
            } finally {
                updatePost(post.id) { it.copy(isLiking = false) }
            }
        }
    }

    private fun updatePost(postId: String, update: (PostDetailUiState) -> PostDetailUiState) {
        mutableState.update { if (it.post?.id == postId) update(it) else it }
    }
}
