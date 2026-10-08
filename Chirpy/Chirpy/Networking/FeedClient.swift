//
//  FeedClient.swift
//  Chirpy
//
//  Created by Samuel Yanez on 8/31/26.
//

import Foundation

// MARK: - FeedServicing

nonisolated protocol FeedServicing: Sendable {
	func createPost(text: String) async throws -> Post

	func fetchPage(
		cursor: String?,
		limit: Int
	) async throws -> SocialFeedPage

	func searchPosts(
		query: String,
		cursor: String?,
		limit: Int
	) async throws -> SocialFeedPage

	func setLike(
		postID: UUID,
		isLiked: Bool
	) async throws -> PostLikeUpdate
}

// MARK: - FeedClient

nonisolated struct FeedClient: FeedServicing {

	private let baseURL: URL

	private let httpClient: any HTTPClient

	private var decoder: JSONDecoder {
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		return decoder
	}

	init(
		baseURL: URL,
		httpClient: any HTTPClient = URLSessionHTTPClient()
	) {
		self.baseURL = baseURL
		self.httpClient = httpClient
	}

	func fetchPage(
		cursor: String? = nil,
		limit: Int = 20
	) async throws -> SocialFeedPage {
		try Task.checkCancellation()
		var components = URLComponents(
			url: baseURL.appending(path: "functions/v1/feed"),
			resolvingAgainstBaseURL: false
		)

		components?.queryItems = [
			URLQueryItem(name: "limit", value: String(limit)),
			cursor.map { URLQueryItem(name: "cursor", value: $0) }
		]
		.compactMap(\.self)

		guard let url = components?.url else {
			throw URLError(.badURL)
		}

		let page: SocialFeedPage = try await send(URLRequest(url: url))
		try Task.checkCancellation()
		return page
	}

	/// Searches post text, passing the server's cursor back unchanged with the same query.
	func searchPosts(
		query: String,
		cursor: String? = nil,
		limit: Int = 20
	) async throws -> SocialFeedPage {
		try Task.checkCancellation()
		var components = URLComponents(
			url: baseURL.appending(path: "functions/v1/search"),
			resolvingAgainstBaseURL: false
		)

		components?.queryItems = [
			URLQueryItem(name: "q", value: query),
			URLQueryItem(name: "limit", value: String(limit)),
			cursor.map { URLQueryItem(name: "cursor", value: $0) }
		]
		.compactMap(\.self)

		// URLSearchParams on the backend reads an unescaped plus as a space.
		let encodedQuery = components?.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
		components?.percentEncodedQuery = encodedQuery

		guard let url = components?.url else {
			throw URLError(.badURL)
		}

		let page: SocialFeedPage = try await send(URLRequest(url: url))
		try Task.checkCancellation()
		return page
	}

	func createPost(text: String) async throws -> Post {
		var request = URLRequest(url: baseURL.appending(path: "functions/v1/posts"))
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.httpBody = try JSONEncoder().encode(["text": text])
		return try await send(request)
	}

	func setLike(
		postID: UUID,
		isLiked: Bool
	) async throws -> PostLikeUpdate {
		let url = baseURL.appending(
			path: "functions/v1/posts/\(postID)/like"
		)

		var request = URLRequest(url: url)
		request.httpMethod = isLiked ? "POST" : "DELETE"

		return try await send(request)
	}

	private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
		let (data, response) = try await httpClient.send(request: request)
		guard let response = response as? HTTPURLResponse else {
			throw URLError(.badServerResponse)
		}

		let decoder = decoder
		guard 200..<300 ~= response.statusCode else {
			throw try decoder.decode(APIErrorResponse.self, from: data).error
		}

		return try decoder.decode(Response.self, from: data)
	}
}

// MARK: - APIErrorResponse

nonisolated struct APIErrorResponse: Decodable, Sendable {
	let error: APIError
}

// MARK: - APIError

nonisolated struct APIError: Error, Decodable, Equatable, Sendable {
	let code: String
	let message: String
	let requestID: UUID
}
