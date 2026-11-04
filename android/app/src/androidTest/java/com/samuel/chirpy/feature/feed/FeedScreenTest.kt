package com.samuel.chirpy.feature.feed

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import com.samuel.chirpy.core.model.Post
import com.samuel.chirpy.core.model.Profile
import com.samuel.chirpy.core.ui.ChirpyTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import java.time.Instant

class FeedScreenTest {
    @get:Rule val compose = createComposeRule()

    @Test
    fun initialErrorOffersRetry() {
        var retries = 0
        compose.setContent {
            ChirpyTheme {
                FeedScreen(
                    FeedUiState(isLoading = false, initialError = FeedMessage.LoadFailed),
                    { retries++ },
                    {},
                    {},
                    {},
                )
            }
        }
        compose.onNodeWithText("The feed couldn’t be loaded.").assertIsDisplayed()
        compose.onNodeWithText("Try again").performClick()
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
                    FeedUiState(posts = listOf(post), isLoading = false),
                    {},
                    {},
                    { likedId = it },
                    {},
                )
            }
        }
        compose.onNodeWithText("Pip Sparrow @crumbclub").assertIsDisplayed()
        compose.onNodeWithText("Hello flock!").assertIsDisplayed()
        compose.onNodeWithContentDescription("Like post").performClick()
        assertEquals("one", likedId)
    }

    @Test
    fun emptyFeedHasRefreshAction() {
        var refreshes = 0
        compose.setContent {
            ChirpyTheme { FeedScreen(FeedUiState(isLoading = false), { refreshes++ }, {}, {}, {}) }
        }
        compose.onNodeWithText("It’s quiet here").assertIsDisplayed()
        compose.onNodeWithContentDescription("Refresh feed").performClick()
        assertEquals(1, refreshes)
    }
}
