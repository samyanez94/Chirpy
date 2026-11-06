package com.samuel.chirpy.feature.social

import androidx.activity.OnBackPressedDispatcher
import androidx.activity.compose.LocalOnBackPressedDispatcherOwner
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.platform.SoftwareKeyboardController
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.hasAnyAncestor
import androidx.compose.ui.test.hasClickAction
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.isDialog
import androidx.compose.ui.test.isSelectable
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import com.samuel.chirpy.core.ui.ChirpyTheme
import org.junit.Rule
import org.junit.Test

class SocialNavigationTest {
    @get:Rule val compose = createComposeRule()
    private lateinit var backDispatcher: OnBackPressedDispatcher
    private var keyboard: SoftwareKeyboardController? = null

    private fun showApp() {
        val repository = NavigationTestRepository()
        compose.setContent {
            backDispatcher = checkNotNull(LocalOnBackPressedDispatcherOwner.current)
                .onBackPressedDispatcher
            keyboard = LocalSoftwareKeyboardController.current
            ChirpyTheme { SocialRoute(repository) }
        }
    }

    private fun closeSoftKeyboard() {
        compose.runOnIdle { keyboard?.hide() }
        compose.waitForIdle()
    }

    private fun pressBack() {
        compose.runOnIdle { backDispatcher.onBackPressed() }
        compose.waitForIdle()
    }

    @Test fun detailAndComposerReturnToSearchAndKeepDraft() {
        showApp()
        compose.onNode(hasText("Search") and isSelectable()).performClick()
        compose.onNodeWithText("Search posts").performTextInput("flock")
        closeSoftKeyboard()
        compose.waitUntil(5_000) {
            compose.onAllNodes(hasText("Hello flock")).fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithText("Hello flock").performClick()
        compose.onNodeWithText("Back").assertIsDisplayed()
        pressBack()
        compose.onNode(hasText("Search") and isSelectable()).assertIsSelected()
        compose.onNodeWithText("flock").assertIsDisplayed()
        compose.onNodeWithContentDescription("New post").performClick()
        compose.onNodeWithText("Post text").performTextInput("Draft survives back")
        closeSoftKeyboard()
        pressBack()
        compose.onNode(hasText("Search") and isSelectable()).assertIsSelected()
        compose.onNodeWithContentDescription("New post").performClick()
        compose.onNodeWithText("Draft survives back").assertIsDisplayed()
        compose.onNodeWithText("Cancel").performClick()
        pressBack()
        compose.onNode(hasText("Home") and isSelectable()).assertIsSelected()
    }

    @Test fun publishAndDeleteReturnToTimeline() {
        showApp()
        compose.onNodeWithContentDescription("New post").performClick()
        compose.onNodeWithText("Post text").performTextInput("New chirp")
        closeSoftKeyboard()
        compose.onNodeWithText("Post").performClick()
        compose.onNodeWithContentDescription("New post").assertIsDisplayed()
        compose.onNodeWithText("Hello flock").performClick()
        compose.onNodeWithText("Delete post").performClick()
        compose.onNodeWithText("Delete this post? This cannot be undone.").assertIsDisplayed()
        compose.onNode(
            hasText("Delete post") and hasClickAction() and hasAnyAncestor(isDialog()),
        ).performClick()
        compose.onNodeWithContentDescription("New post").assertIsDisplayed()
    }
}
