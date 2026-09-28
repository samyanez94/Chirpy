//
//  FeedClientTests.swift
//  ChirpyTests
//
//  Created by Samuel Yanez on 8/31/26.
//

import Foundation
import Testing

@testable import Chirpy

struct FeedClientTests {
	@Test func testFetchPage() async throws {
		let data = try fixtureData(named: "social-feed-page")
		let baseURL = try #require(URL(string: "https://example.com"))
		let response = try httpResponse(url: baseURL, statusCode: 200)
		let client = FeedClient(
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
		let client = FeedClient(
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
		let client = FeedClient(
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
		let client = FeedClient(
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
		let client = FeedClient(
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
		let client = FeedClient(
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
		let client = FeedClient(
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
		let client = FeedClient(
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
		let client = FeedClient(
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
		let client = FeedClient(
			baseURL: baseURL,
			httpClient: HTTPClientStub(data: Data(), response: response)
		)

		let error = try await #require(throws: URLError.self) {
			try await client.setLike(postID: UUID(), isLiked: true)
		}
		#expect(error.code == .badServerResponse)
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

	init(data: Data, response: URLResponse, recorder: RequestRecorder? = nil) {
		self.data = data
		self.response = response
		self.recorder = recorder
	}

	func send(request: URLRequest) async throws -> (Data, URLResponse) {
		await recorder?.record(request)
		return (data, response)
	}
}

private actor RequestRecorder {
	private var requests: [URLRequest] = []

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
