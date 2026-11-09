package com.samuel.chirpy.feature.postdetail

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import com.samuel.chirpy.core.data.CurrentProfileState
import com.samuel.chirpy.core.model.Post
import com.samuel.chirpy.core.model.Profile
import com.samuel.chirpy.core.ui.ChirpyTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import java.time.Instant

class PostDetailScreenTest {
    @get:Rule val compose = createComposeRule()
    private val profile = Profile("me", "bird", "Bird", null)
    private val post = Post("post", profile, "Hello flock", null, Instant.EPOCH, false, 2)

    @Test fun deletionRequiresConfirmationAndCancelKeepsPost() {
        var deletions = 0
        compose.setContent {
            ChirpyTheme {
                PostDetailScreen(
                    post,
                    PostDetailUiState(),
                    CurrentProfileState(
                        profile = profile,
                    ),
                    {
                    },
                    { deletions++ },
                    {},
                    {},
                )
            }
        }
        compose.onNodeWithText("Delete post").performClick()
        compose.onNodeWithText("Delete this post? This cannot be undone.").assertIsDisplayed()
        assertEquals(0, deletions)
        compose.onNodeWithText("Cancel").performClick()
        compose.onNodeWithText("Hello flock").assertIsDisplayed()
        assertEquals(0, deletions)
    }

    @Test fun otherAuthorsHaveNoDeleteControl() {
        compose.setContent {
            ChirpyTheme {
                PostDetailScreen(
                    post,
                    PostDetailUiState(),
                    CurrentProfileState(profile = profile.copy(id = "other")),
                    {
                    },
                    {},
                    {},
                    {},
                )
            }
        }
        compose.onNodeWithText("Delete post").assertDoesNotExist()
        compose.onNodeWithText("Hello flock").assertIsDisplayed()
    }
}
