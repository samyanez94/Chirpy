package com.samuel.chirpy.core.data

import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

internal class PostMutationCoordinator {
    private class Entry(val mutex: Mutex = Mutex(), var users: Int = 0)

    private val guard = Mutex()
    private val entries = mutableMapOf<String, Entry>()
    private val mutablePending = MutableStateFlow<Set<String>>(emptySet())
    val pending = mutablePending.asStateFlow()

    suspend fun <T> mutate(postId: String, operation: suspend () -> T): T {
        val entry = guard.withLock {
            entries.getOrPut(postId) { Entry() }.also {
                it.users++
                mutablePending.value = entries.keys.toSet()
            }
        }
        try {
            return entry.mutex.withLock { operation() }
        } finally {
            // A cancelled waiter must release its registration without removing another caller's lock.
            withContext(NonCancellable) {
                guard.withLock {
                    entry.users--
                    if (entry.users == 0) entries.remove(postId)
                    mutablePending.value = entries.keys.toSet()
                }
            }
        }
    }
}
