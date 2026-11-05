package com.samuel.chirpy.core.network

import com.samuel.chirpy.core.data.ApiException
import com.samuel.chirpy.core.data.MissingApiKeyException
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.test.runTest
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import java.time.Instant

class NetworkFeedRepositoryTest {
    private val server = MockWebServer()

    @Before
    fun setUp() {
        server.start()
    }

    @After
    fun tearDown() {
        server.shutdown()
    }

    @Test
    fun decodesFeedAndPassesOpaqueCursorWithApiKey() = runTest {
        val body = checkNotNull(javaClass.getResource("/social-feed-page.json")).readText()
        server.enqueue(MockResponse().setBody(body))
        val repository = NetworkFeedRepository.create(server.url("/").toString(), "test-key")
        val page = repository.fetchPage("cursor+with/symbols=", 20)
        val request = server.takeRequest()
        assertEquals("test-key", request.getHeader("X-Chirpy-API-Key"))
        assertEquals("cursor+with/symbols=", request.requestUrl?.queryParameter("cursor"))
        assertEquals("20", request.requestUrl?.queryParameter("limit"))
        assertEquals("/functions/v1/feed", request.requestUrl?.encodedPath)
        assertEquals(Instant.parse("2026-08-31T19:42:17.123Z"), page.posts.single().createdAt)
        assertEquals("Corvid Crow", page.posts.single().author.displayName)
        assertEquals("opaque-next-page-cursor", page.nextCursor)
    }

    @Test
    fun preservesApiErrorCodeAndRequestId() = runTest {
        server.enqueue(
            MockResponse()
                .setResponseCode(400)
                .setBody(
                    """{"error":{"code":"invalid_cursor","message":"Invalid cursor","requestID":"request-123"}}""",
                ),
        )
        val repository = NetworkFeedRepository.create(server.url("/").toString(), "test-key")
        try {
            repository.fetchPage("bad", 20)
            fail("Expected API error")
        } catch (error: ApiException) {
            assertEquals("invalid_cursor", error.code)
            assertEquals("request-123", error.requestId)
            assertEquals(400, error.status)
        }
    }

    @Test
    fun nonJsonServerFailureHasSafeFallback() = runTest {
        server.enqueue(MockResponse().setResponseCode(502).setBody("Bad Gateway"))
        val repository = NetworkFeedRepository.create(server.url("/").toString(), "test-key")
        try {
            repository.fetchPage(null, 20)
            fail("Expected API error")
        } catch (error: ApiException) {
            assertEquals("http_error", error.code)
            assertEquals(502, error.status)
        }
    }

    @Test
    fun missingKeyDoesNotSendRequest() = runTest {
        val repository = NetworkFeedRepository.create(server.url("/").toString(), "")
        try {
            repository.fetchPage(null, 20)
            fail("Expected configuration error")
        } catch (_: MissingApiKeyException) {
            assertEquals(0, server.requestCount)
        }
    }

    @Test
    fun likeAndUnlikeUseCorrectMethods() = runTest {
        val repository = NetworkFeedRepository.create(server.url("/").toString(), "test-key")
        for ((liked, method) in listOf(true to "POST", false to "DELETE")) {
            server.enqueue(
                MockResponse().setBody("""{"postID":"post","isLiked":$liked,"likeCount":3}"""),
            )
            assertEquals(liked, repository.setLike("post", liked).isLiked)
            val request = server.takeRequest()
            assertEquals(method, request.method)
            assertEquals("/functions/v1/posts/post/like", request.path)
        }
    }

    @Test
    fun searchAndProfileRequestsPreserveFiltersAndCursors() = runTest {
        val repository = NetworkFeedRepository.create(server.url("/").toString(), "test-key")
        val body = checkNotNull(javaClass.getResource("/social-feed-page.json")).readText()
        server.enqueue(MockResponse().setBody(body))
        repository.searchPosts("birds + 🐦 & trees", "next+/=", 20)
        val search = server.takeRequest()
        assertEquals("/functions/v1/search", search.requestUrl?.encodedPath)
        assertEquals("birds + 🐦 & trees", search.requestUrl?.queryParameter("q"))
        assertEquals("next+/=", search.requestUrl?.queryParameter("cursor"))
        server.enqueue(MockResponse().setBody(body))
        repository.profilePosts("profile-id", "opaque", 20)
        val profile = server.takeRequest()
        assertEquals("profile-id", profile.requestUrl?.queryParameter("profile_id"))
        assertEquals("opaque", profile.requestUrl?.queryParameter("cursor"))
    }

    @Test
    fun profileCreationAndDeletionUseSharedApiContract() = runTest {
        val repository = NetworkFeedRepository.create(server.url("/").toString(), "test-key")
        server.enqueue(
            MockResponse().setBody("""{"id":"me","username":"bird","displayName":"Bird"}"""),
        )
        assertEquals("me", repository.currentProfile().id)
        assertEquals("/functions/v1/profile", server.takeRequest().path)
        val page = kotlinx.serialization.json.Json.parseToJsonElement(
            checkNotNull(javaClass.getResource("/social-feed-page.json")).readText(),
        ) as kotlinx.serialization.json.JsonObject
        val post = (page.getValue("posts") as kotlinx.serialization.json.JsonArray).first()
        server.enqueue(MockResponse().setBody(post.toString()))
        repository.createPost("Hello 🐦")
        val create = server.takeRequest()
        assertEquals("POST", create.method)
        assertEquals("/functions/v1/posts", create.path)
        assertEquals("""{"text":"Hello 🐦"}""", create.body.readUtf8())
        server.enqueue(MockResponse().setResponseCode(204))
        repository.deletePost("post")
        val delete = server.takeRequest()
        assertEquals("DELETE", delete.method)
        assertEquals("/functions/v1/posts/post", delete.path)
    }

    @Test
    fun missingPostDeletionSucceedsButForbiddenDeletionFails() = runTest {
        val repository = NetworkFeedRepository.create(server.url("/").toString(), "test-key")
        server.enqueue(
            MockResponse().setResponseCode(404).setBody(
                """{"error":{"code":"post_not_found","message":"Gone","requestID":"request"}}""",
            ),
        )
        repository.deletePost("gone")
        server.enqueue(
            MockResponse().setResponseCode(403).setBody(
                """{"error":{"code":"forbidden","message":"Not yours","requestID":"request"}}""",
            ),
        )
        try {
            repository.deletePost("other")
            fail("Expected forbidden deletion")
        } catch (error: ApiException) {
            assertEquals("forbidden", error.code)
        }
    }

    @Test
    fun concurrentProfileLoadsShareCacheAndFailedRefreshPreservesProfile() = runTest {
        val repository = NetworkFeedRepository.create(server.url("/").toString(), "test-key")
        server.enqueue(
            MockResponse().setBody("""{"id":"me","username":"bird","displayName":"Bird"}"""),
        )
        val profiles = List(2) { async { repository.currentProfile() } }.awaitAll()
        assertEquals(listOf("me", "me"), profiles.map { it.id })
        assertEquals(1, server.requestCount)
        assertEquals("Bird", repository.currentProfileState.value.profile?.displayName)
        server.enqueue(MockResponse().setResponseCode(503))
        try {
            repository.currentProfile(refresh = true)
            fail("Expected refresh failure")
        } catch (_: ApiException) {
            assertEquals(true, repository.currentProfileState.value.hasFailed)
            assertEquals(false, repository.currentProfileState.value.isLoading)
            assertEquals("Bird", repository.currentProfileState.value.profile?.displayName)
        }
        server.enqueue(
            MockResponse().setBody("""{"id":"me","username":"bird","displayName":"Updated"}"""),
        )
        repository.currentProfile(refresh = true)
        assertEquals("Updated", repository.currentProfileState.value.profile?.displayName)
        assertEquals(false, repository.currentProfileState.value.hasFailed)
    }
}
