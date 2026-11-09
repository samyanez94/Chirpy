package com.samuel.chirpy.feature.postcomposer

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.samuel.chirpy.core.data.SocialRepository
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class PostComposerViewModel(private val repository: SocialRepository) : ViewModel() {
    private val mutableState = MutableStateFlow(PostComposerUiState())
    val state = mutableState.asStateFlow()

    fun open() {
        mutableState.update { it.copy(hasFailed = false) }
    }

    fun editDraft(text: String) {
        if (!state.value.isPosting) mutableState.update { it.copy(draft = text) }
    }

    fun publish(onPublished: () -> Unit) {
        val draft = state.value
        if (!draft.canPublish) return
        mutableState.update { it.copy(isPosting = true, hasFailed = false) }
        viewModelScope.launch {
            try {
                repository.createPost(PostDraft.trimmed(draft.draft))
            } catch (error: CancellationException) {
                throw error
            } catch (_: Exception) {
                mutableState.update { it.copy(hasFailed = true) }
                return@launch
            } finally {
                mutableState.update { it.copy(isPosting = false) }
            }
            mutableState.value = PostComposerUiState()
            onPublished()
        }
    }
}
