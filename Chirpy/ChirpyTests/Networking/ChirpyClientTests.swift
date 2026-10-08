//
//  ChirpyClientTests.swift
//  ChirpyTests
//
//  Created by Samuel Yanez on 8/31/26.
//

import Foundation
import Testing

@testable import Chirpy

struct ChirpyClientTests {
	@Test func testFetchPage() async throws {
		let data = try fixtureData(named: "social-feed-page")
		let baseURL = try #require(URL(string: "https://example.com"))
		let response = try httpResponse(url: baseURL, statusCode: 200)
		let client = ChirpyClient(
			baseURL: baseURL,
			httpClient: HTTPClientStub(data: data, response: response)
		)

		let page = try await client.fetchPage()

		#expect(page.posts.count == 1)
		#expect(page.nextCursor == "opaque-next-page-cursor")
	}

	@Test func testFetchPageBuildsRequest() async throws {
		let data = try fixtureData(named: "social-feed-page")
		let baseURL = try #require(URL(string: "https://example.com"))
		let response = try httpResponse(url: baseURL, statusCode: 200)
		let recorder = RequestRecorder()
		let client = ChirpyClient(
			baseURL: baseURL,
			httpClient: HTTPClientStub(
				data: data,
				response: response,
				recorder: recorder
			)
		)

		_ = try await client.fetchPage(cursor: "opaque cursor/+", limit: 10)

		let recordedRequest = await recorder.onlyRequest()
		let request = try #require(recordedRequest)
		let url = try #require(request.url)
		let components = try #require(
			URLComponents(url: url, resolvingAgainstBaseURL: false)
		)

		#expect(request.httpMethod == "GET")
		#expect(components.path == "/functions/v1/feed")
		#expect(components.queryItems?.first { $0.name == "limit" }?.value == "10")
		#expect(components.queryItems?.first { $0.name == "cursor" }?.value == "opaque cursor/+")
	}

	@Test func testFetchPageThrowsAPIError() async throws {
		let data = try fixtureData(named: "service-unavailable-error")
		let baseURL = try #require(URL(string: "https://example.com"))
		let response = try httpResponse(url: baseURL, statusCode: 503)
		let client = ChirpyClient(
			baseURL: baseURL,
			httpClient: HTTPClientStub(data: data, response: response)
		)

		let error = try await #require(throws: APIError.self) {
			try await client.fetchPage()
		}
		#expect(error.code == "service_unavailable")
		#expect(error.message == "A development failure was requested.")
		#expect(error.requestID.uuidString == "00000000-0000-4000-8000-000000000001")
	}

	@Test func testFetchPageRejectsNonHTTPResponse() async throws {
		let baseURL = try #require(URL(string: "https://example.com"))
		let response = URLResponse(
			url: baseURL,
			mimeType: "application/json",
			expectedContentLength: 0,
			textEncodingName: nil
		)
		let client = ChirpyClient(
			baseURL: baseURL,
			httpClient: HTTPClientStub(data: Data(), response: response)
		)

		let error = try await #require(throws: URLError.self) {
			try await client.fetchPage()
		}
		#expect(error.code == .badServerResponse)
	}

	@Test func testCreatePost() async throws {
		let fixture = try #require(JSONSerialization.jsonObject(with: fixtureData(named: "social-feed-page")) as? [String: Any])
		let posts = try #require(fixture["posts"] as? [[String: Any]])
		let data = try JSONSerialization.data(withJSONObject: #require(posts.first))
		let baseURL = URL(string: "https://example.com")!
		let recorder = RequestRecorder()
		let client = ChirpyClient(
			baseURL: baseURL,
			httpClient: HTTPClientStub(
				data: data,
				response: try httpResponse(url: baseURL, statusCode: 201),
				recorder: recorder
			)
		)
		let post = try await client.createPost(text: "Hello\nChirpy")
		let request = try #require(await recorder.onlyRequest())
		#expect(request.httpMethod == "POST")
		#expect(request.url?.path == "/functions/v1/posts")
		#expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
		let payload = try JSONDecoder().decode([String: String].self, from: #require(request.httpBody))
		#expect(payload == ["text": "Hello\nChirpy"])
		#expect(post.id.uuidString.lowercased() == posts[0]["id"] as? String)
	}

	@Test func testCreatePostPropagatesAPIError() async throws {
		let baseURL = URL(string: "https://example.com")!
		let client = ChirpyClient(
			baseURL: baseURL,
			httpClient: HTTPClientStub(
				data: try fixtureData(named: "service-unavailable-error"),
				response: try httpResponse(url: baseURL, statusCode: 503)
			)
		)
		await #expect(throws: APIError.self) { try await client.createPost(text: "Hello") }
	}

	@Test func testSetLike() async throws {
		let data = try fixtureData(named: "post-like-update")
		let baseURL = try #require(URL(string: "https://example.com"))
		let response = try httpResponse(url: baseURL, statusCode: 200)
		let client = ChirpyClient(
			baseURL: baseURL,
			httpClient: HTTPClientStub(data: data, response: response)
		)
		let postID = try #require(
			UUID(uuidString: "10000000-0000-4000-8000-000000000001")
		)

		let update = try await client.setLike(postID: postID, isLiked: true)

		#expect(update.postID == postID)
		#expect(update.isLiked)
		#expect(update.likeCount == 13)
	}

	@Test(arguments: [true, false])
	func testSetLikeBuildsRequest(isLiked: Bool) async throws {
		let data = try fixtureData(named: "post-like-update")
		let baseURL = try #require(URL(string: "https://example.com"))
		let response = try httpResponse(url: baseURL, statusCode: 200)
		let recorder = RequestRecorder()
		let client = ChirpyClient(
			baseURL: baseURL,
			httpClient: HTTPClientStub(
				data: data,
				response: response,
				recorder: recorder
			)
		)
		let postID = try #require(
			UUID(uuidString: "10000000-0000-4000-8000-000000000001")
		)

		_ = try await client.setLike(postID: postID, isLiked: isLiked)

		let recordedRequest = await recorder.onlyRequest()
		let request = try #require(recordedRequest)
		#expect(request.httpMethod == (isLiked ? "POST" : "DELETE"))
		#expect(
			request.url?.path
				== "/functions/v1/posts/\(postID)/like"
		)
	}

	@Test func testSetLikeThrowsAPIError() async throws {
		let data = try fixtureData(named: "service-unavailable-error")
		let baseURL = try #require(URL(string: "https://example.com"))
		let response = try httpResponse(url: baseURL, statusCode: 503)
		let client = ChirpyClient(
			baseURL: baseURL,
			httpClient: HTTPClientStub(data: data, response: response)
		)
		let postID = UUID()

		let error = try await #require(throws: APIError.self) {
			try await client.setLike(postID: postID, isLiked: true)
		}
		#expect(error.code == "service_unavailable")
		#expect(error.message == "A development failure was requested.")
		#expect(error.requestID.uuidString == "00000000-0000-4000-8000-000000000001")
	}

	@Test func testSetLikeRejectsNonHTTPResponse() async throws {
		let baseURL = try #require(URL(string: "https://example.com"))
		let response = URLResponse(
			url: baseURL,
			mimeType: "application/json",
			expectedContentLength: 0,
			textEncodingName: nil
		)
		let client = ChirpyClient(
			baseURL: baseURL,
			httpClient: HTTPClientStub(data: Data(), response: response)
		)

		let error = try await #require(throws: URLError.self) {
			try await client.setLike(postID: UUID(), isLiked: true)
		}
		#expect(error.code == .badServerResponse)
	}

	@Test func testSearchPostsDecodesPageAndBuildsDefaultRequest() async throws {
		let baseURL = try #require(URL(string: "https://example.com"))
		let recorder = RequestRecorder()
		let client = ChirpyClient(
			baseURL: baseURL,
			httpClient: HTTPClientStub(
				data: try fixtureData(named: "social-feed-page"),
				response: try httpResponse(url: baseURL, statusCode: 200),
				recorder: recorder
			)
		)

		let page = try await client.searchPosts(query: "bottle")
		let post = try #require(page.posts.first)
		#expect(page.posts.count == 1)
		#expect(page.nextCursor == "opaque-next-page-cursor")
		#expect(post.text == "Found a bottle cap. My retirement plan is coming together.")
		#expect(post.author.username == "shinycollector")
		#expect(post.isLiked)
		#expect(post.likeCount == 12)
		#expect(post.imageURL?.absoluteString == "https://example.com/posts/chirpy.jpg")

		let request = try #require(await recorder.onlyRequest())
		let url = try #require(request.url)
		let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
		#expect(request.httpMethod == "GET")
		#expect(components.path == "/functions/v1/search")
		#expect(
			components.queryItems == [
				URLQueryItem(name: "q", value: "bottle"),
				URLQueryItem(name: "limit", value: "20")
			]
		)
	}

	@Test func testSearchPostsEncodesQueryAndOpaqueCursor() async throws {
		let baseURL = try #require(URL(string: "https://example.com"))
		let recorder = RequestRecorder()
		let client = ChirpyClient(
			baseURL: baseURL,
			httpClient: HTTPClientStub(
				data: try fixtureData(named: "social-feed-page"),
				response: try httpResponse(url: baseURL, statusCode: 200),
				recorder: recorder
			)
		)
		let query = "crumb & seed+100%/😀?=#"
		let cursor = "opaque cursor/+"
		_ = try await client.searchPosts(query: query, cursor: cursor, limit: 7)

		let request = try #require(await recorder.onlyRequest())
		let url = try #require(request.url)
		let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
		#expect(
			components.queryItems == [
				URLQueryItem(name: "q", value: query),
				URLQueryItem(name: "limit", value: "7"),
				URLQueryItem(name: "cursor", value: cursor)
			]
		)
		let encodedQuery = try #require(components.percentEncodedQuery)
		#expect(!encodedQuery.contains("+"))
		#expect(encodedQuery.contains("%2B"))
	}

	@Test func testSearchPostsDecodesEmptyResultsAndAuthenticates() async throws {
		let baseURL = try #require(URL(string: "https://example.com"))
		let recorder = RequestRecorder()
		let client = ChirpyClient(
			baseURL: baseURL,
			httpClient: AuthenticatedHTTPClient(
				apiKey: "test-key",
				transport: HTTPClientStub(
					data: Data(#"{"posts":[],"nextCursor":null,"hasMore":false}"#.utf8),
					response: try httpResponse(url: baseURL, statusCode: 200),
					recorder: recorder
				)
			)
		)

		let page = try await client.searchPosts(query: "no matches")
		#expect(page.posts.isEmpty)
		#expect(page.nextCursor == nil)
		let request = try #require(await recorder.onlyRequest())
		#expect(request.value(forHTTPHeaderField: "X-Chirpy-API-Key") == "test-key")
	}

	@Test func testSearchPostsRequiresAuthenticationBeforeSending() async throws {
		let baseURL = try #require(URL(string: "https://example.com"))
		let recorder = RequestRecorder()
		let client = ChirpyClient(
			baseURL: baseURL,
			httpClient: AuthenticatedHTTPClient(
				apiKey: nil,
				transport: HTTPClientStub(
					data: Data(),
					response: try httpResponse(url: baseURL, statusCode: 200),
					recorder: recorder
				)
			)
		)

		let error = try await #require(throws: URLError.self) {
			try await client.searchPosts(query: "crumb")
		}
		#expect(error.code == .userAuthenticationRequired)
		#expect(await recorder.count == 0)
	}

	@Test(arguments: [
		(400, "invalid_request"),
		(400, "invalid_cursor"),
		(401, "unauthorized"),
		(500, "internal_error")
	])
	func testSearchPostsPreservesAPIError(statusCode: Int, code: String) async throws {
		let baseURL = try #require(URL(string: "https://example.com"))
		let data = try JSONSerialization.data(withJSONObject: [
			"error": [
				"code": code,
				"message": "Search failed.",
				"requestID": "00000000-0000-4000-8000-000000000001"
			]
		])
		let client = ChirpyClient(
			baseURL: baseURL,
			httpClient: HTTPClientStub(
				data: data,
				response: try httpResponse(url: baseURL, statusCode: statusCode)
			)
		)

		let error = try await #require(throws: APIError.self) {
			try await client.searchPosts(query: "crumb")
		}
		#expect(error.code == code)
		#expect(error.message == "Search failed.")
		#expect(error.requestID.uuidString == "00000000-0000-4000-8000-000000000001")
	}

	@Test(arguments: [false, true])
	func testSearchPostsHonorsCancellation(afterSending: Bool) async throws {
		let baseURL = try #require(URL(string: "https://example.com"))
		let recorder = RequestRecorder()
		let client = ChirpyClient(
			baseURL: baseURL,
			httpClient: HTTPClientStub(
				data: try fixtureData(named: "social-feed-page"),
				response: try httpResponse(url: baseURL, statusCode: 200),
				recorder: recorder,
				onSend: {
					if afterSending {
						withUnsafeCurrentTask { $0?.cancel() }
					}
				}
			)
		)

		let task = Task {
			if !afterSending {
				withUnsafeCurrentTask { $0?.cancel() }
			}
			return try await client.searchPosts(query: "crumb")
		}
		await #expect(throws: CancellationError.self) { try await task.value }
		#expect(await recorder.count == (afterSending ? 1 : 0))
	}

	@Test(arguments: [false, true])
	func testFetchCurrentProfileDecodesAuthorAndAuthenticates(hasAvatar: Bool) async throws {
		let baseURL = try #require(URL(string: "https://example.com"))
		let profileID = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000001"))
		let avatarURL = hasAvatar ? "https://example.com/avatar.jpg" : nil
		let data = try JSONSerialization.data(withJSONObject: [
			"id": profileID.uuidString,
			"username": "crumbclub",
			"displayName": "Pip Sparrow",
			"avatarURL": avatarURL as Any? ?? NSNull()
		])
		let recorder = RequestRecorder()
		let client = ChirpyClient(
			baseURL: baseURL,
			httpClient: AuthenticatedHTTPClient(
				apiKey: "test-key",
				transport: HTTPClientStub(
					data: data,
					response: try httpResponse(url: baseURL, statusCode: 200),
					recorder: recorder
				)
			)
		)

		let profile = try await client.fetchCurrentProfile()

		#expect(profile.id == profileID)
		#expect(profile.username == "crumbclub")
		#expect(profile.displayName == "Pip Sparrow")
		#expect(profile.avatarURL?.absoluteString == avatarURL)
		let request = try #require(await recorder.onlyRequest())
		#expect(request.httpMethod == "GET")
		#expect(request.url?.path == "/functions/v1/profile")
		#expect(request.url?.query == nil)
		#expect(request.value(forHTTPHeaderField: "X-Chirpy-API-Key") == "test-key")
	}

	@Test(arguments: [false, true])
	func testFetchPageBuildsOptionalProfileFilter(isFiltered: Bool) async throws {
		let baseURL = try #require(URL(string: "https://example.com"))
		let profileID = try #require(UUID(uuidString: "ABCDEF00-0000-4000-8000-000000000001"))
		let recorder = RequestRecorder()
		let client = ChirpyClient(
			baseURL: baseURL,
			httpClient: AuthenticatedHTTPClient(
				apiKey: "test-key",
				transport: HTTPClientStub(
					data: try fixtureData(named: "social-feed-page"),
					response: try httpResponse(url: baseURL, statusCode: 200),
					recorder: recorder
				)
			)
		)
		let page = try await client.fetchPage(
			profileID: isFiltered ? profileID : nil,
			cursor: "opaque cursor/+",
			limit: 7
		)

		#expect(page.posts.count == 1)
		#expect(page.nextCursor == "opaque-next-page-cursor")
		let request = try #require(await recorder.onlyRequest())
		let url = try #require(request.url)
		let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
		#expect(request.httpMethod == "GET")
		#expect(components.path == "/functions/v1/feed")
		var expected = [URLQueryItem(name: "limit", value: "7")]
		if isFiltered {
			expected.append(URLQueryItem(name: "profile_id", value: profileID.uuidString.lowercased()))
		}
		expected.append(URLQueryItem(name: "cursor", value: "opaque cursor/+"))
		#expect(components.queryItems == expected)
		#expect(request.value(forHTTPHeaderField: "X-Chirpy-API-Key") == "test-key")
	}

	@Test(arguments: [false, true])
	func testProfileRequestsRequireAuthenticationBeforeSending(fetchProfile: Bool) async throws {
		let baseURL = try #require(URL(string: "https://example.com"))
		let recorder = RequestRecorder()
		let client = ChirpyClient(
			baseURL: baseURL,
			httpClient: AuthenticatedHTTPClient(
				apiKey: nil,
				transport: HTTPClientStub(
					data: Data(),
					response: try httpResponse(url: baseURL, statusCode: 200),
					recorder: recorder
				)
			)
		)
		let error = try await #require(throws: URLError.self) {
			if fetchProfile {
				_ = try await client.fetchCurrentProfile()
			} else {
				_ = try await client.fetchPage(profileID: UUID())
			}
		}
		#expect(error.code == .userAuthenticationRequired)
		#expect(await recorder.count == 0)
	}

	@Test(arguments: [false, true], [(400, "invalid_cursor"), (401, "unauthorized"), (500, "internal_error")])
	func testProfileRequestsPreserveAPIErrors(fetchProfile: Bool, failure: (Int, String)) async throws {
		let baseURL = try #require(URL(string: "https://example.com"))
		let requestID = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000001"))
		let data = try JSONSerialization.data(withJSONObject: [
			"error": ["code": failure.1, "message": "Request failed.", "requestID": requestID.uuidString]
		])
		let client = ChirpyClient(
			baseURL: baseURL,
			httpClient: HTTPClientStub(data: data, response: try httpResponse(url: baseURL, statusCode: failure.0))
		)
		let error = try await #require(throws: APIError.self) {
			if fetchProfile {
				_ = try await client.fetchCurrentProfile()
			} else {
				_ = try await client.fetchPage(profileID: UUID())
			}
		}
		#expect(error.code == failure.1)
		#expect(error.message == "Request failed.")
		#expect(error.requestID == requestID)
	}

	@Test(arguments: [false, true], [false, true])
	func testProfileRequestsHonorCancellation(fetchProfile: Bool, afterSending: Bool) async throws {
		let baseURL = try #require(URL(string: "https://example.com"))
		let recorder = RequestRecorder()
		let data: Data
		if fetchProfile {
			let fixture = try #require(JSONSerialization.jsonObject(with: fixtureData(named: "social-feed-page")) as? [String: Any])
			let posts = try #require(fixture["posts"] as? [[String: Any]])
			let post = try #require(posts.first)
			data = try JSONSerialization.data(withJSONObject: #require(post["author"]))
		} else {
			data = try fixtureData(named: "social-feed-page")
		}
		let client = ChirpyClient(
			baseURL: baseURL,
			httpClient: HTTPClientStub(
				data: data,
				response: try httpResponse(url: baseURL, statusCode: 200),
				recorder: recorder,
				onSend: {
					if afterSending {
						withUnsafeCurrentTask { $0?.cancel() }
					}
				}
			)
		)
		let task = Task {
			if !afterSending {
				withUnsafeCurrentTask { $0?.cancel() }
			}
			if fetchProfile {
				_ = try await client.fetchCurrentProfile()
			} else {
				_ = try await client.fetchPage(profileID: UUID())
			}
		}
		await #expect(throws: CancellationError.self) { try await task.value }
		#expect(await recorder.count == (afterSending ? 1 : 0))
	}

	private func fixtureData(named name: String) throws -> Data {
		let fixtureURL = try #require(
			Bundle(for: NetworkingTestBundleToken.self)
				.url(
					forResource: name,
					withExtension: "json"
				)
		)
		return try Data(contentsOf: fixtureURL)
	}

	private func httpResponse(url: URL, statusCode: Int) throws -> HTTPURLResponse {
		try #require(
			HTTPURLResponse(
				url: url,
				statusCode: statusCode,
				httpVersion: nil,
				headerFields: nil
			)
		)
	}
}

private nonisolated struct HTTPClientStub: HTTPClient {
	let data: Data
	let response: URLResponse
	let recorder: RequestRecorder?
	let onSend: (@Sendable () async throws -> Void)?

	init(
		data: Data,
		response: URLResponse,
		recorder: RequestRecorder? = nil,
		onSend: (@Sendable () async throws -> Void)? = nil
	) {
		self.data = data
		self.response = response
		self.recorder = recorder
		self.onSend = onSend
	}

	func send(request: URLRequest) async throws -> (Data, URLResponse) {
		await recorder?.record(request)
		try await onSend?()
		return (data, response)
	}
}

private actor RequestRecorder {
	private var requests: [URLRequest] = []

	var count: Int { requests.count }

	func record(_ request: URLRequest) {
		requests.append(request)
	}

	func onlyRequest() -> URLRequest? {
		guard requests.count == 1 else {
			return nil
		}
		return requests[0]
	}
}

private final class NetworkingTestBundleToken {}
