package com.samuel.chirpy.feature.feed

import com.samuel.chirpy.core.data.PostChange
import com.samuel.chirpy.core.model.FeedPage
import com.samuel.chirpy.core.model.LikeUpdate
import com.samuel.chirpy.testing.FakeSocialRepository
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.withContext
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class FilteredFeedTest {
    private val dispatcher = StandardTestDispatcher()
    private val repository = FakeSocialRepository()

    @Before fun setUp() {
        Dispatchers.setMain(dispatcher)
    }

    @After fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test fun searchDebouncesAndRejectsNonCancellableOldResponse() = runTest(dispatcher) {
        val old = CompletableDeferred<FeedPage>()
        repository.search = { query, _ ->
            if (query == "old") {
                withContext(NonCancellable) { old.await() }
            } else {
                FeedPage(listOf(repository.post(query)), null)
            }
        }
        val model = FeedViewModel(repository, FeedMode.Search)
        model.search("o")
        advanceTimeBy(100)
        model.search("old")
        advanceTimeBy(300)
        runCurrent()
        assertEquals(listOf("old" to null), repository.searchRequests)
        model.search("new")
        advanceTimeBy(300)
        runCurrent()
        old.complete(FeedPage(listOf(repository.post("old")), null))
        advanceUntilIdle()
        assertEquals(listOf("new"), model.state.value.posts.map { it.id })
        model.search("  ")
        advanceUntilIdle()
        assertTrue(model.state.value.posts.isEmpty())
        assertFalse(model.state.value.isLoading)
    }

    @Test fun searchPaginationKeepsQueryAndStopsRepeatedCursor() = runTest(dispatcher) {
        repository.search =
            { _, cursor -> FeedPage(listOf(repository.post(cursor ?: "first")), "next") }
        val model = FeedViewModel(repository, FeedMode.Search)
        model.search("  birds + trees  ")
        advanceUntilIdle()
        model.loadMore()
        advanceUntilIdle()
        model.loadMore()
        advanceUntilIdle()
        assertEquals(
            listOf("birds + trees" to null, "birds + trees" to "next"),
            repository.searchRequests,
        )
        assertEquals(listOf("first", "next"), model.state.value.posts.map { it.id })
    }

    @Test fun profilePaginationAlwaysIncludesCurrentProfileId() = runTest(dispatcher) {
        repository.page =
            { cursor ->
                FeedPage(
                    listOf(repository.post(cursor ?: "first")),
                    if (cursor ==
                        null
                    ) {
                        "next"
                    } else {
                        null
                    },
                )
            }
        val model = FeedViewModel(repository, FeedMode.Profile)
        advanceUntilIdle()
        model.loadMore()
        advanceUntilIdle()
        assertEquals(listOf("me" to null, "me" to "next"), repository.profileRequests)
    }

    @Test fun deletionAndLikeEventsWinOverInflightPages() = runTest(dispatcher) {
        repository.page = { FeedPage(listOf(repository.post("deleted")), "next") }
        val model = FeedViewModel(repository)
        advanceUntilIdle()
        val response = CompletableDeferred<FeedPage>()
        repository.page = { response.await() }
        model.loadMore()
        runCurrent()
        repository.changes.emit(PostChange.Deleted("deleted"))
        repository.changes.emit(PostChange.Liked(LikeUpdate("liked", true, 8)))
        runCurrent()
        response.complete(
            FeedPage(listOf(repository.post("deleted"), repository.post("liked")), null),
        )
        advanceUntilIdle()
        assertEquals(listOf("liked"), model.state.value.posts.map { it.id })
        assertEquals(8, model.state.value.posts.single().likeCount)
        assertTrue(model.state.value.posts.single().isLiked)
    }

    @Test fun creationRefreshesAllLoadedTimelines() = runTest(dispatcher) {
        val home = FeedViewModel(repository)
        val profile = FeedViewModel(repository, FeedMode.Profile)
        advanceUntilIdle()
        repository.page = { FeedPage(listOf(repository.post("new")), null) }
        repository.changes.emit(PostChange.Created)
        advanceUntilIdle()
        assertEquals("new", home.state.value.posts.single().id)
        assertEquals("new", profile.state.value.posts.single().id)
    }
}
