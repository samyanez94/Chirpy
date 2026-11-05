package com.samuel.chirpy.feature.social

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
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
class SocialViewModelTest {
    private val dispatcher = StandardTestDispatcher()
    private val repository = FakeSocialRepository()

    @Before fun setUp() {
        Dispatchers.setMain(dispatcher)
    }

    @After fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test fun backStackKeepsTimelineAndNeverPopsItsRoot() = runTest(dispatcher) {
        val model = SocialViewModel(repository)
        model.close()
        assertEquals(listOf(SocialDestination.Timeline), model.state.value.backStack)
        model.compose()
        model.compose()
        assertEquals(
            listOf(SocialDestination.Timeline, SocialDestination.Composer),
            model.state.value.backStack,
        )
        model.editDraft("Keep my draft")
        model.close()
        model.compose()
        assertEquals("Keep my draft", model.state.value.composer.draft)
        model.close()
        model.openPost(repository.post("post"))
        val detailStack = model.state.value.backStack
        model.toggleLike()
        advanceUntilIdle()
        assertEquals(detailStack, model.state.value.backStack)
        assertEquals(SocialDestination.Detail("post"), detailStack.last())
        assertTrue(model.state.value.selectedPost!!.isLiked)
        model.close()
        model.close()
        assertEquals(listOf(SocialDestination.Timeline), model.state.value.backStack)
        repository.pendingPostIds.value = setOf("post")
        advanceUntilIdle()
        model.compose()
        model.close()
        assertEquals(listOf(SocialDestination.Timeline), model.state.value.backStack)
    }

    @Test fun pendingDetailMutationBlocksBackUntilCompletion() = runTest(dispatcher) {
        val response = CompletableDeferred<Unit>()
        repository.like = { id, liked ->
            response.await()
            com.samuel.chirpy.core.model.LikeUpdate(id, liked, 1)
        }
        val model = SocialViewModel(repository)
        model.openPost(repository.post("post"))
        model.toggleLike()
        model.close()
        assertEquals(SocialDestination.Detail("post"), model.state.value.destination)
        response.complete(Unit)
        advanceUntilIdle()
        model.close()
        assertEquals(listOf(SocialDestination.Timeline), model.state.value.backStack)
    }

    @Test fun draftValidationMatchesServerUnicodeRules() {
        assertTrue(PostDraft.isValid("🐦".repeat(300)))
        assertFalse(PostDraft.isValid("🐦".repeat(301)))
        assertFalse(PostDraft.isValid("\uFEFF \n"))
        assertEquals("\u0085", PostDraft.trimmed("\u0085"))
        assertEquals(2, PostDraft.count("e\u0301"))
    }

    @Test fun failedPublishKeepsDraftAndRetryPublishesTrimmedText() = runTest(dispatcher) {
        val model = SocialViewModel(repository)
        model.compose()
        model.editDraft("  Hello 🐦 \uFEFF")
        repository.create = { throw IOException() }
        model.publish()
        advanceUntilIdle()
        assertEquals(SocialDestination.Composer, model.state.value.destination)
        assertEquals("  Hello 🐦 \uFEFF", model.state.value.composer.draft)
        assertTrue(model.state.value.composer.hasFailed)
        repository.create = { text ->
            assertEquals("Hello 🐦", text)
            repository.post("new")
        }
        model.publish()
        advanceUntilIdle()
        assertEquals(SocialDestination.Timeline, model.state.value.destination)
        assertEquals("", model.state.value.composer.draft)
    }

    @Test fun postingBlocksDuplicateSubmissionAndDismissal() = runTest(dispatcher) {
        val response = CompletableDeferred<Unit>()
        var calls = 0
        repository.create = {
            calls++
            response.await()
            repository.post("new")
        }
        val model = SocialViewModel(repository)
        model.compose()
        model.editDraft("A new chirp")
        model.publish()
        model.publish()
        model.close()
        model.editDraft("Replacement")
        runCurrent()
        assertEquals(1, calls)
        assertEquals(SocialDestination.Composer, model.state.value.destination)
        assertEquals("A new chirp", model.state.value.composer.draft)
        response.complete(Unit)
        advanceUntilIdle()
        assertFalse(model.state.value.composer.isPosting)
    }

    @Test fun deletionChecksOwnershipAndPreservesDetailOnFailure() = runTest(dispatcher) {
        val model = SocialViewModel(repository)
        advanceUntilIdle()
        var calls = 0
        repository.delete = {
            calls++
            throw IOException()
        }
        val own = repository.post("mine")
        model.openPost(own.copy(author = repository.profile.copy(id = "other")))
        model.delete()
        advanceUntilIdle()
        assertEquals(0, calls)
        model.openPost(own)
        model.delete()
        advanceUntilIdle()
        assertEquals(own, model.state.value.selectedPost)
        assertTrue(model.state.value.detail.hasFailed)
        repository.delete = {}
        model.delete()
        advanceUntilIdle()
        assertEquals(SocialDestination.Timeline, model.state.value.destination)
    }

    @Test fun detailLikeFailureLeavesCountAndAllowsRetry() = runTest(dispatcher) {
        val model = SocialViewModel(repository)
        model.openPost(repository.post("post"))
        repository.like = { _, _ -> throw IOException() }
        model.toggleLike()
        advanceUntilIdle()
        assertEquals(
            0,
            model.state.value.selectedPost?.likeCount,
        )
        assertFalse(model.state.value.detail.isLiking)
        assertTrue(model.state.value.detail.hasFailed)
    }

    @Test fun sharedPendingMutationDisablesDetailUntilItCompletes() = runTest(dispatcher) {
        val model = SocialViewModel(repository)
        advanceUntilIdle()
        repository.pendingPostIds.value = setOf("post")
        model.openPost(repository.post("post"))
        var calls = 0
        repository.like = { id, liked ->
            calls++
            com.samuel.chirpy.core.model.LikeUpdate(id, liked, 1)
        }
        model.toggleLike()
        advanceUntilIdle()
        assertTrue(model.state.value.detail.isBusy)
        assertEquals(0, calls)
        repository.pendingPostIds.value = emptySet()
        advanceUntilIdle()
        model.toggleLike()
        advanceUntilIdle()
        assertEquals(1, calls)
        assertFalse(model.state.value.detail.isBusy)
        assertEquals(true, model.state.value.selectedPost!!.isLiked)
    }
}
