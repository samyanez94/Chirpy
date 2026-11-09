package com.samuel.chirpy.app

import com.samuel.chirpy.testing.FakeSocialRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

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
        model.open(AppDestination.Composer)
        model.open(AppDestination.Composer)
        assertEquals(
            listOf(AppDestination.Timeline, AppDestination.Composer),
            model.state.value.backStack,
        )
        model.close()
        model.close()
        assertEquals(listOf(AppDestination.Timeline), model.state.value.backStack)
    }

    @Test fun onlyDeletionOfTheOpenPostClosesDetail() = runTest(dispatcher) {
        val model = SocialViewModel(repository)
        advanceUntilIdle()
        model.open(AppDestination.Detail("open"))
        repository.deletePost("other")
        advanceUntilIdle()
        assertEquals(AppDestination.Detail("open"), model.state.value.destination)
        repository.deletePost("open")
        advanceUntilIdle()
        assertEquals(AppDestination.Timeline, model.state.value.destination)
    }
}
