package com.samuel.chirpy.feature.postdetail

import com.samuel.chirpy.testing.FakeSocialRepository
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.IOException

@OptIn(ExperimentalCoroutinesApi::class)
class PostDetailViewModelTest {
    private val dispatcher = StandardTestDispatcher()
    private val repository = FakeSocialRepository()

    @Before fun setUp() {
        Dispatchers.setMain(dispatcher)
    }

    @After fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test fun detailIsBusyUntilLikeCompletes() = runTest(dispatcher) {
        val response = CompletableDeferred<Unit>()
        repository.like = { id, liked ->
            response.await()
            com.samuel.chirpy.core.model.LikeUpdate(id, liked, 1)
        }
        val model = PostDetailViewModel(repository)
        model.open(repository.post("post"))
        model.toggleLike()
        assertTrue(model.state.value.isBusy)
        response.complete(Unit)
        advanceUntilIdle()
        assertFalse(model.state.value.isBusy)
    }

    @Test fun deletionChecksOwnershipAndPreservesDetailOnFailure() = runTest(dispatcher) {
        repository.currentProfile()
        val model = PostDetailViewModel(repository)
        advanceUntilIdle()
        var calls = 0
        repository.delete = {
            calls++
            throw IOException()
        }
        val own = repository.post("mine")
        model.open(own.copy(author = repository.profile.copy(id = "other")))
        model.delete()
        advanceUntilIdle()
        assertEquals(0, calls)
        model.open(own)
        model.delete()
        advanceUntilIdle()
        assertEquals(own, model.state.value.post)
        assertTrue(model.state.value.hasFailed)
        repository.delete = {}
        model.delete()
        advanceUntilIdle()
        assertEquals(null, model.state.value.post)
    }

    @Test fun detailLikeFailureLeavesCountAndAllowsRetry() = runTest(dispatcher) {
        val model = PostDetailViewModel(repository)
        model.open(repository.post("post"))
        repository.like = { _, _ -> throw IOException() }
        model.toggleLike()
        advanceUntilIdle()
        assertEquals(
            0,
            model.state.value.post?.likeCount,
        )
        assertFalse(model.state.value.isLiking)
        assertTrue(model.state.value.hasFailed)
    }

    @Test fun lateLikeFailureCannotChangeTheNextPost() = runTest(dispatcher) {
        val response = CompletableDeferred<Unit>()
        repository.like = { _, _ ->
            response.await()
            throw IOException()
        }
        val model = PostDetailViewModel(repository)
        model.open(repository.post("first"))
        model.toggleLike()
        advanceUntilIdle()
        repository.deletePost("first")
        advanceUntilIdle()
        val second = repository.post("second")
        model.open(second)
        response.complete(Unit)
        advanceUntilIdle()
        assertEquals(PostDetailUiState(post = second), model.state.value)
    }

    @Test fun sharedPendingMutationDisablesDetailUntilItCompletes() = runTest(dispatcher) {
        val model = PostDetailViewModel(repository)
        advanceUntilIdle()
        repository.pendingPostIds.value = setOf("post")
        model.open(repository.post("post"))
        var calls = 0
        repository.like = { id, liked ->
            calls++
            com.samuel.chirpy.core.model.LikeUpdate(id, liked, 1)
        }
        model.toggleLike()
        advanceUntilIdle()
        assertTrue(model.state.value.isBusy)
        assertEquals(0, calls)
        repository.pendingPostIds.value = emptySet()
        advanceUntilIdle()
        model.toggleLike()
        advanceUntilIdle()
        assertEquals(1, calls)
        assertFalse(model.state.value.isBusy)
        assertEquals(true, model.state.value.post!!.isLiked)
    }
}
