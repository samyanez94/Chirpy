package com.samuel.chirpy.core.data

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class PostMutationCoordinatorTest {
    @Test fun serializesOnePostWhileAllowingAnotherPostToProgress() = runTest {
        val coordinator = PostMutationCoordinator()
        val release = CompletableDeferred<Unit>()
        val completed = mutableListOf<String>()
        launch {
            coordinator.mutate("one") {
                release.await()
                completed.add("first")
            }
        }
        launch { coordinator.mutate("one") { completed.add("second") } }
        launch { coordinator.mutate("two") { completed.add("other") } }
        runCurrent()
        assertEquals(listOf("other"), completed)
        assertEquals(setOf("one"), coordinator.pending.value)
        release.complete(Unit)
        runCurrent()
        assertEquals(listOf("other", "first", "second"), completed)
        assertTrue(coordinator.pending.value.isEmpty())
    }

    @Test fun cancelledWaiterDoesNotClearAnActiveMutation() = runTest {
        val coordinator = PostMutationCoordinator()
        val release = CompletableDeferred<Unit>()
        val active = launch { coordinator.mutate("one") { release.await() } }
        val waiting = launch { coordinator.mutate("one") { error("Cancelled waiter ran") } }
        runCurrent()
        waiting.cancel()
        waiting.join()
        assertEquals(setOf("one"), coordinator.pending.value)
        active.cancel()
        active.join()
        assertTrue(coordinator.pending.value.isEmpty())
        coordinator.mutate("one") { assertEquals(setOf("one"), coordinator.pending.value) }
        assertTrue(coordinator.pending.value.isEmpty())
    }
}
