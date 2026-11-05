package com.samuel.chirpy.feature.feed

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasScrollToIndexAction
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.StateRestorationTester
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToIndex
import androidx.compose.ui.test.performScrollToNode
import androidx.test.platform.app.InstrumentationRegistry
import com.samuel.chirpy.R
import com.samuel.chirpy.core.model.Post
import com.samuel.chirpy.core.model.Profile
import com.samuel.chirpy.core.ui.ChirpyTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import java.time.Instant

class FeedScreenTest {
    @get:Rule val compose = createComposeRule()
    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    @Test
    fun initialErrorOffersRetry() {
        var retries = 0
        compose.setContent {
            ChirpyTheme {
                FeedScreen(
                    state = FeedUiState(isLoading = false, initialError = FeedMessage.LoadFailed),
                    onRefresh = { retries++ },
                    onLoadMore = {},
                    onLike = {},
                    onMessageDismissed = {},
                )
            }
        }
        compose.onNodeWithText(context.getString(R.string.feed_error)).assertIsDisplayed()
        compose.onNodeWithText(context.getString(R.string.retry)).performClick()
        assertEquals(1, retries)
    }

    @Test
    fun postDisplaysAuthorTextAndAccessibleLikeAction() {
        var likedId: String? = null
        val post =
            Post(
                "one",
                Profile("author", "crumbclub", "Pip Sparrow", null),
                "Hello flock!",
                null,
                Instant.EPOCH,
                false,
                3,
            )
        compose.setContent {
            ChirpyTheme {
                FeedScreen(
                    state = FeedUiState(posts = listOf(post), isLoading = false),
                    onRefresh = {},
                    onLoadMore = {},
                    onLike = { likedId = it },
                    onMessageDismissed = {},
                )
            }
        }
        val handle = context.getString(R.string.handle, post.author.username)
        compose.onNodeWithText("${post.author.displayName} $handle").assertIsDisplayed()
        compose.onNodeWithText("Hello flock!").assertIsDisplayed()
        compose.onNodeWithContentDescription(context.getString(R.string.like)).performClick()
        assertEquals("one", likedId)
    }

    @Test
    fun emptyFeedHasRefreshAction() {
        var refreshes = 0
        compose.setContent {
            ChirpyTheme {
                FeedScreen(
                    state = FeedUiState(isLoading = false),
                    onRefresh = { refreshes++ },
                    onLoadMore = {},
                    onLike = {},
                    onMessageDismissed = {},
                )
            }
        }
        compose.onNodeWithText(context.getString(R.string.empty_title)).assertIsDisplayed()
        compose.onNodeWithContentDescription(context.getString(R.string.refresh)).performClick()
        assertEquals(1, refreshes)
    }

    @Test
    fun paginationContinuesAfterDuplicatePageAndWaitsForRetryAfterFailure() {
        var state by mutableStateOf(
            FeedUiState(
                posts = List(40) {
                    feedPost(it)
                },
                isLoading = false,
                nextCursor = "page-2",
            ),
        )
        var requests = 0
        compose.setContent {
            ChirpyTheme {
                FeedScreen(
                    state = state,
                    onRefresh = {},
                    onLoadMore = {
                        requests++
                        state = state.copy(isLoadingMore = true, paginationFailed = false)
                    },
                    onLike = {},
                    onMessageDismissed = {},
                )
            }
        }
        compose.runOnIdle { assertEquals(0, requests) }
        compose.onNode(hasScrollToIndexAction()).performScrollToIndex(35)
        compose.runOnIdle { assertEquals(1, requests) }

        // A duplicate-only page advances the cursor without adding visible posts.
        compose.runOnIdle { state = state.copy(nextCursor = "page-3", isLoadingMore = false) }
        compose.runOnIdle { assertEquals(2, requests) }

        compose.runOnIdle { state = state.copy(isLoadingMore = false, paginationFailed = true) }
        compose.onNode(hasScrollToIndexAction())
            .performScrollToNode(hasText(context.getString(R.string.retry)))
        compose.runOnIdle { assertEquals(2, requests) }
        compose.onNodeWithText(context.getString(R.string.retry)).performClick()
        compose.runOnIdle { assertEquals(3, requests) }
    }

    @Test
    fun scrollPositionSurvivesStateRestoration() {
        val restoration = StateRestorationTester(compose)
        val state = FeedUiState(posts = List(40) { feedPost(it) }, isLoading = false)
        restoration.setContent {
            ChirpyTheme {
                FeedScreen(
                    state = state,
                    onRefresh = {},
                    onLoadMore = {},
                    onLike = {},
                    onMessageDismissed = {},
                )
            }
        }
        compose.onNode(hasScrollToIndexAction()).performScrollToIndex(20)
        val post = compose.onNodeWithText("Post 20").assertIsDisplayed()
        val originalBounds = post.fetchSemanticsNode().boundsInRoot

        restoration.emulateSavedInstanceStateRestore()

        post.assertIsDisplayed()
        assertEquals(originalBounds, post.fetchSemanticsNode().boundsInRoot)
    }

    private fun feedPost(index: Int) = Post(
        id = "post-$index",
        author = Profile("author", "crumbclub", "Pip Sparrow", null),
        text = "Post $index",
        imageUrl = null,
        createdAt = Instant.EPOCH,
        isLiked = false,
        likeCount = 0,
    )
}
