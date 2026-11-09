package com.samuel.chirpy.app

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.samuel.chirpy.core.data.PostChange
import com.samuel.chirpy.core.data.SocialRepository
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
            repository.changes.collect { change ->
                if (change is PostChange.Deleted &&
                    state.value.destination == AppDestination.Detail(change.id)
                ) {
                    close()
                }
            }
        }
        loadProfile()
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

    fun open(destination: AppDestination) {
        if (destination != AppDestination.Timeline &&
            state.value.destination == AppDestination.Timeline
        ) {
            mutableState.update {
                it.copy(backStack = listOf(AppDestination.Timeline, destination))
            }
        }
    }

    fun close() {
        mutableState.update { it.copy(backStack = listOf(AppDestination.Timeline)) }
    }
}
