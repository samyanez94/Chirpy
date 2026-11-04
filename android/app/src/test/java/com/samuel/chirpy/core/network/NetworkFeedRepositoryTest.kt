package com.samuel.chirpy.core.network

import com.samuel.chirpy.core.data.ApiException
import com.samuel.chirpy.core.data.MissingApiKeyException
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
}
