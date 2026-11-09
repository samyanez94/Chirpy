package com.samuel.chirpy.app

import androidx.activity.OnBackPressedDispatcher
import androidx.activity.compose.LocalOnBackPressedDispatcherOwner
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.platform.SoftwareKeyboardController
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.hasAnyAncestor
import androidx.compose.ui.test.hasClickAction
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.isDialog
import androidx.compose.ui.test.isSelectable
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import com.samuel.chirpy.core.ui.ChirpyTheme
import kotlinx.coroutines.CompletableDeferred
import org.junit.Rule
import org.junit.Test

class AppNavigationTest {
    @get:Rule val compose = createComposeRule()
    private lateinit var backDispatcher: OnBackPressedDispatcher
    private var keyboard: SoftwareKeyboardController? = null

    private fun showApp(repository: NavigationTestRepository = NavigationTestRepository()) {
        compose.setContent {
            backDispatcher = checkNotNull(LocalOnBackPressedDispatcherOwner.current)
                .onBackPressedDispatcher
            keyboard = LocalSoftwareKeyboardController.current
            ChirpyTheme { ChirpyAppRoot(repository) }
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

    private fun openComposer() {
        val newPostButton = hasContentDescription("New post") and hasClickAction()
        // Returning to a tab can expose its selection before the FAB semantics are ready.
        compose.waitUntil(5_000) {
            compose.onAllNodes(newPostButton).fetchSemanticsNodes().size == 1
        }
        compose.onNode(newPostButton).assertIsDisplayed().performClick()
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
        compose.onNodeWithContentDescription("Back").assertIsDisplayed().performClick()
        compose.onNode(hasText("Search") and isSelectable()).assertIsSelected()
        compose.onNodeWithText("flock").assertIsDisplayed()
        compose.onNodeWithText("Hello flock").performClick()
        pressBack()
        compose.onNode(hasText("Search") and isSelectable()).assertIsSelected()
        compose.onNodeWithText("flock").assertIsDisplayed()
        openComposer()
        compose.onNodeWithText("Post text").performTextInput("Draft survives back")
        closeSoftKeyboard()
        pressBack()
        compose.onNode(hasText("Search") and isSelectable()).assertIsSelected()
        openComposer()
        compose.onNodeWithText("Draft survives back").assertIsDisplayed()
        compose.onNodeWithContentDescription("Close").assertIsDisplayed().performClick()
        compose.onNode(hasText("Search") and isSelectable()).assertIsSelected()
        openComposer()
        compose.onNodeWithText("Draft survives back").assertIsDisplayed()
        compose.onNodeWithContentDescription("Close").performClick()
        pressBack()
        compose.onNode(hasText("Home") and isSelectable()).assertIsSelected()
    }

    @Test fun backWaitsForPublishAndDetailLikeToFinish() {
        val publish = CompletableDeferred<Unit>()
        val like = CompletableDeferred<Unit>()
        showApp(
            NavigationTestRepository(beforePublish = {
                publish.await()
            }, beforeLike = { like.await() }),
        )
        openComposer()
        compose.onNodeWithText("Post text").performTextInput("Pending post")
        closeSoftKeyboard()
        compose.onNodeWithText("Post").performClick()
        pressBack()
        compose.onNodeWithText("Pending post").assertIsDisplayed()
        publish.complete(Unit)
        compose.onNodeWithText("Hello flock").performClick()
        compose.onNodeWithContentDescription("Like post").performClick()
        pressBack()
        compose.onNodeWithContentDescription("Back").assertIsDisplayed()
        like.complete(Unit)
        compose.onNodeWithContentDescription("Unlike post").assertIsDisplayed()
        pressBack()
        compose.onNode(hasText("Home") and isSelectable()).assertIsSelected()
    }

    @Test fun draftFollowsComposerFromSearchToProfile() {
        showApp()
        compose.onNode(hasText("Search") and isSelectable()).performClick()
        openComposer()
        compose.onNodeWithText("Post text").performTextInput("One shared draft")
        closeSoftKeyboard()
        pressBack()
        compose.onNode(hasText("Profile") and isSelectable()).performClick()
        openComposer()
        compose.onNodeWithText("One shared draft").assertIsDisplayed()
    }

    @Test fun publishingFromSearchAndProfileReturnsToTheOriginatingTab() {
        showApp()
        for (tab in listOf("Search", "Profile")) {
            val tabItem = compose.onNode(hasText(tab) and isSelectable())
            tabItem.performClick()
            openComposer()
            compose.onNodeWithText("Post text").performTextInput("Posting from $tab")
            closeSoftKeyboard()
            compose.onNodeWithText("Post").performClick()
            tabItem.assertIsSelected()
        }
    }

    @Test fun publishAndDeleteReturnToTimeline() {
        showApp()
        openComposer()
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
