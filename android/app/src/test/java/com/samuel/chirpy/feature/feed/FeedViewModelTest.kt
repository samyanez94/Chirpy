package com.samuel.chirpy.feature.feed

import com.samuel.chirpy.core.data.ApiException
import com.samuel.chirpy.core.data.FeedRepository
import com.samuel.chirpy.core.data.MissingApiKeyException
import com.samuel.chirpy.core.model.FeedPage
import com.samuel.chirpy.core.model.LikeUpdate
import com.samuel.chirpy.core.model.Post
import com.samuel.chirpy.core.model.Profile
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.withContext
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.IOException
import java.time.Instant

@OptIn(ExperimentalCoroutinesApi::class)
class FeedViewModelTest {
    private val dispatcher = StandardTestDispatcher()
    private val repository = FakeRepository()

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun firstPageLoadsAndDuplicatesAreRemoved() = runTest(dispatcher) {
        repository.page = { _, limit ->
            assertEquals(20, limit)
            FeedPage(listOf(post("one"), post("one")), "next")
        }
        val model = FeedViewModel(repository)
        advanceUntilIdle()
        assertEquals(listOf("one"), model.state.value.posts.map { it.id })
        assertEquals("next", model.state.value.nextCursor)
        assertFalse(model.state.value.isLoading)
    }

    @Test
    fun paginationDeduplicatesAndSuppressesOverlappingRequests() = runTest(dispatcher) {
        repository.page = { _, _ -> FeedPage(listOf(post("one")), "next") }
        val model = FeedViewModel(repository)
        advanceUntilIdle()
        val response = CompletableDeferred<FeedPage>()
        repository.page = { cursor, _ ->
            assertEquals("next", cursor)
            response.await()
        }
        model.loadMore()
        model.loadMore()
        runCurrent()
        assertEquals(2, repository.pageCalls)
        response.complete(FeedPage(listOf(post("one"), post("two")), null))
        advanceUntilIdle()
        assertEquals(listOf("one", "two"), model.state.value.posts.map { it.id })
        assertNull(model.state.value.nextCursor)
    }

    @Test
    fun refreshDiscardsLatePaginationEvenIfTransportIgnoresCancellation() = runTest(dispatcher) {
        repository.page = { _, _ -> FeedPage(listOf(post("old")), "next") }
        val model = FeedViewModel(repository)
        advanceUntilIdle()
        val oldResponse = CompletableDeferred<FeedPage>()
        repository.page = { cursor, _ ->
            if (cursor != null) {
                withContext(NonCancellable) { oldResponse.await() }
            } else {
                FeedPage(listOf(post("new")), null)
            }
        }
        model.loadMore()
        runCurrent()
        model.refresh()
        runCurrent()
        oldResponse.complete(FeedPage(listOf(post("stale")), null))
        advanceUntilIdle()
        assertEquals(listOf("new"), model.state.value.posts.map { it.id })
    }

    @Test
    fun refreshFailureRetainsContent() = runTest(dispatcher) {
        val model = FeedViewModel(repository)
        advanceUntilIdle()
        repository.page = { _, _ -> throw IOException() }
        model.refresh()
        advanceUntilIdle()
        assertEquals(1, model.state.value.posts.size)
        assertEquals(FeedMessage.RefreshFailed, model.state.value.message)
        assertNull(model.state.value.initialError)
        assertFalse(model.state.value.isRefreshing)
    }

    @Test
    fun initialFailureCanBeRetried() = runTest(dispatcher) {
        repository.page = { _, _ -> throw IOException() }
        val model = FeedViewModel(repository)
        advanceUntilIdle()
        assertEquals(FeedMessage.LoadFailed, model.state.value.initialError)
        repository.page = { _, _ -> FeedPage(emptyList(), null) }
        model.refresh()
        advanceUntilIdle()
        assertNull(model.state.value.initialError)
        assertFalse(model.state.value.isLoading)
    }

    @Test
    fun missingKeyHasActionableConfigurationState() = runTest(dispatcher) {
        repository.page = { _, _ -> throw MissingApiKeyException() }
        val model = FeedViewModel(repository)
        advanceUntilIdle()
        assertEquals(FeedMessage.MissingConfiguration, model.state.value.initialError)
    }

    @Test
    fun paginationFailureRetainsCursorForRetry() = runTest(dispatcher) {
        repository.page = { _, _ -> FeedPage(listOf(post("one")), "next") }
        val model = FeedViewModel(repository)
        advanceUntilIdle()
        repository.page = { _, _ -> throw IOException() }
        model.loadMore()
        advanceUntilIdle()
        assertTrue(model.state.value.paginationFailed)
        assertEquals("next", model.state.value.nextCursor)
        repository.page = { _, _ -> FeedPage(listOf(post("two")), null) }
        model.loadMore()
        advanceUntilIdle()
        assertEquals(2, model.state.value.posts.size)
        assertFalse(model.state.value.paginationFailed)
    }

    @Test
    fun invalidCursorRestartsFromFirstPage() = runTest(dispatcher) {
        repository.page = { _, _ -> FeedPage(listOf(post("one")), "invalid") }
        val model = FeedViewModel(repository)
        advanceUntilIdle()
        repository.page = { cursor, _ ->
            if (cursor != null) throw ApiException("invalid_cursor", 400, null)
            FeedPage(listOf(post("fresh")), null)
        }
        model.loadMore()
        advanceUntilIdle()
        assertEquals("fresh", model.state.value.posts.single().id)
    }

    @Test
    fun repeatedCursorStopsAutomaticPagination() = runTest(dispatcher) {
        repository.page = { _, _ -> FeedPage(listOf(post("one")), "same") }
        val model = FeedViewModel(repository)
        advanceUntilIdle()
        model.loadMore()
        advanceUntilIdle()
        assertNull(model.state.value.nextCursor)
        assertEquals(1, model.state.value.posts.size)
    }

    @Test
    fun likesUseServerResultAndSuppressDuplicateActions() = runTest(dispatcher) {
        val model = FeedViewModel(repository)
        advanceUntilIdle()
        val response = CompletableDeferred<LikeUpdate>()
        repository.like = { _, liked ->
            assertTrue(liked)
            response.await()
        }
        model.toggleLike("one")
        model.toggleLike("one")
        runCurrent()
        assertEquals(1, repository.likeCalls)
        assertFalse(model.state.value.posts.single().isLiked)
        response.complete(LikeUpdate("one", true, 42))
        advanceUntilIdle()
        assertEquals(42, model.state.value.posts.single().likeCount)
        assertTrue(model.state.value.posts.single().isLiked)
        assertTrue(model.state.value.pendingLikes.isEmpty())
    }

    @Test
    fun likeFailureKeepsPreviousValue() = runTest(dispatcher) {
        val model = FeedViewModel(repository)
        advanceUntilIdle()
        repository.like = { _, _ -> throw IOException() }
        model.toggleLike("one")
        advanceUntilIdle()
        assertFalse(model.state.value.posts.single().isLiked)
        assertEquals(FeedMessage.LikeFailed, model.state.value.message)
        assertTrue(model.state.value.pendingLikes.isEmpty())
    }

    @Test
    fun lateRefreshDoesNotOverwriteCompletedLike() = runTest(dispatcher) {
        val model = FeedViewModel(repository)
        advanceUntilIdle()
        val response = CompletableDeferred<FeedPage>()
        repository.page = { _, _ -> response.await() }
        model.refresh()
        runCurrent()
        model.toggleLike("one")
        runCurrent()
        response.complete(FeedPage(listOf(post("one")), null))
        advanceUntilIdle()
        assertTrue(model.state.value.posts.single().isLiked)
    }

    private class FakeRepository : FeedRepository {
        var pageCalls = 0
        var likeCalls = 0
        var page: suspend (String?, Int) -> FeedPage = { _, _ ->
            FeedPage(listOf(post("one")), null)
        }
        var like: suspend (String, Boolean) -> LikeUpdate = { id, liked ->
            LikeUpdate(id, liked, 1)
        }

        override suspend fun fetchPage(cursor: String?, limit: Int): FeedPage {
            pageCalls++
            return page(cursor, limit)
        }

        override suspend fun setLike(postId: String, isLiked: Boolean): LikeUpdate {
            likeCalls++
            return like(postId, isLiked)
        }
    }

    companion object {
        private fun post(id: String) = Post(
            id,
            Profile("author", "bird", "Bird", null),
            "Hello",
            null,
            Instant.EPOCH,
            false,
            0,
        )
    }
}
