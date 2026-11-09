package com.samuel.chirpy.feature.postcomposer

import com.samuel.chirpy.testing.FakeSocialRepository
import kotlinx.coroutines.CancellationException
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
class PostComposerViewModelTest {
    private val dispatcher = StandardTestDispatcher()
    private val repository = FakeSocialRepository()

    @Before fun setUp() {
        Dispatchers.setMain(dispatcher)
    }

    @After fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test fun draftValidationMatchesServerUnicodeRules() {
        assertTrue(PostDraft.isValid("🐦".repeat(300)))
        assertFalse(PostDraft.isValid("🐦".repeat(301)))
        assertFalse(PostDraft.isValid("\uFEFF \n"))
        assertEquals("\u0085", PostDraft.trimmed("\u0085"))
        assertEquals(2, PostDraft.count("e\u0301"))
    }

    @Test fun failedPublishKeepsDraftAndRetryPublishesTrimmedText() = runTest(dispatcher) {
        val model = PostComposerViewModel(repository)
        var published = 0
        model.editDraft("  Hello 🐦 \uFEFF")
        repository.create = { throw IOException() }
        model.publish { published++ }
        advanceUntilIdle()
        assertEquals(0, published)
        assertEquals("  Hello 🐦 \uFEFF", model.state.value.draft)
        assertTrue(model.state.value.hasFailed)
        repository.create = { text ->
            assertEquals("Hello 🐦", text)
            repository.post("new")
        }
        model.publish { published++ }
        advanceUntilIdle()
        assertEquals(1, published)
        assertEquals("", model.state.value.draft)
    }

    @Test fun cancelledPublishKeepsTheDraftWithoutReportingFailure() = runTest(dispatcher) {
        val model = PostComposerViewModel(repository)
        model.editDraft("Draft")
        repository.create = { throw CancellationException() }
        model.publish { error("Cancelled publish must keep the composer open") }
        advanceUntilIdle()
        assertEquals(PostComposerUiState(draft = "Draft"), model.state.value)
    }

    @Test fun postingBlocksDuplicateSubmissionAndEdits() = runTest(dispatcher) {
        val response = CompletableDeferred<Unit>()
        var calls = 0
        repository.create = {
            calls++
            response.await()
            repository.post("new")
        }
        val model = PostComposerViewModel(repository)
        var published = 0
        model.editDraft("A new chirp")
        model.publish { published++ }
        model.publish { published++ }
        assertTrue(model.state.value.isPosting)
        model.editDraft("Replacement")
        runCurrent()
        assertEquals(1, calls)
        assertEquals(0, published)
        assertEquals("A new chirp", model.state.value.draft)
        response.complete(Unit)
        advanceUntilIdle()
        assertFalse(model.state.value.isPosting)
    }
}
