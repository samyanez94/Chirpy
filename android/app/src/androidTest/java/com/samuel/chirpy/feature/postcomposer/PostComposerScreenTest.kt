package com.samuel.chirpy.feature.postcomposer

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import com.samuel.chirpy.core.ui.ChirpyTheme
import org.junit.Rule
import org.junit.Test

class PostComposerScreenTest {
    @get:Rule val compose = createComposeRule()

    @Test fun composerDisablesEmptySubmissionAndShowsPreservedDraftError() {
        compose.setContent {
            ChirpyTheme {
                PostComposerScreen(PostComposerUiState(hasFailed = true), {}, {}, {})
            }
        }
        compose.onNodeWithText("Post").assertIsNotEnabled()
        compose.onNodeWithText(
            "Couldn’t post. Your draft is still here. Please try again.",
        ).assertIsDisplayed()
    }
}
