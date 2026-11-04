//
//  ChirpyClient.swift
//  Chirpy
//
//  Created by Samuel Yanez on 8/31/26.
//

import Foundation

// MARK: - ChirpyServicing

nonisolated protocol ChirpyServicing: Sendable {

	func fetchPage(
		profileID: UUID?,
		cursor: String?,
		limit: Int
	) async throws -> SocialFeedPage

	func createPost(text: String) async throws -> Post

	func deletePost(postID: UUID) async throws

	func searchPosts(
		query: String,
		cursor: String?,
		limit: Int
	) async throws -> SocialFeedPage

	func setLike(
		postID: UUID,
		isLiked: Bool
	) async throws -> PostLikeUpdate

	func fetchCurrentProfile() async throws -> Profile
}

extension ChirpyServicing {
	/// Fetches the unfiltered Home feed.
	func fetchPage(cursor: String?, limit: Int) async throws -> SocialFeedPage {
		try await fetchPage(profileID: nil, cursor: cursor, limit: limit)
	}
}

// MARK: - ChirpyClient

nonisolated struct ChirpyClient: ChirpyServicing {

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

	/// Fetches posts, optionally filtered by author. Keep the same filter when continuing a cursor.
	func fetchPage(
		profileID: UUID? = nil,
		cursor: String? = nil,
		limit: Int = 20
	) async throws -> SocialFeedPage {
		let url = try makeURL(
			path: "feed",
			queryItems: [
				URLQueryItem(name: "limit", value: String(limit)),
				profileID.map { URLQueryItem(name: "profile_id", value: $0.uuidString.lowercased()) },
				cursor.map { URLQueryItem(name: "cursor", value: $0) }
			]
		)
		return try await send(URLRequest(url: url))
	}

	/// Creates a text-only post as the server-selected profile.
	func createPost(text: String) async throws -> Post {
		var request = URLRequest(url: baseURL.appending(path: "functions/v1/posts"))
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.httpBody = try JSONEncoder().encode(["text": text])
		return try await send(request)
	}

	/// Deletes a post owned by the server-selected profile, returning no response body.
	func deletePost(postID: UUID) async throws {
		let url = baseURL.appending(path: "functions/v1/posts/\(postID.uuidString.lowercased())")
		var request = URLRequest(url: url)
		request.httpMethod = "DELETE"
		let (_, response) = try await sendData(request)
		guard response.statusCode == 204 else {
			throw URLError(.badServerResponse)
		}
	}

	/// Searches post text, passing the server's cursor back unchanged with the same query.
	func searchPosts(
		query: String,
		cursor: String? = nil,
		limit: Int = 20
	) async throws -> SocialFeedPage {
		let url = try makeURL(
			path: "search",
			queryItems: [
				URLQueryItem(name: "q", value: query),
				URLQueryItem(name: "limit", value: String(limit)),
				cursor.map { URLQueryItem(name: "cursor", value: $0) }
			]
		)
		return try await send(URLRequest(url: url))
	}

	/// Sets the server-selected profile’s like and returns the authoritative state and count.
	func setLike(
		postID: UUID,
		isLiked: Bool
	) async throws -> PostLikeUpdate {
		let url = baseURL.appending(
			path: "functions/v1/posts/\(postID.uuidString.lowercased())/like"
		)

		var request = URLRequest(url: url)
		request.httpMethod = isLiked ? "POST" : "DELETE"

		return try await send(request)
	}

	/// Fetches the server-selected current profile, even when it has no posts.
	func fetchCurrentProfile() async throws -> Profile {
		let url = baseURL.appending(path: "functions/v1/profile")
		return try await send(URLRequest(url: url))
	}

	/// Encodes query values consistently for the backend's URLSearchParams parser.
	private func makeURL(path: String, queryItems: [URLQueryItem?]) throws -> URL {
		guard var components = URLComponents(
            url: baseURL.appending(path: "functions/v1/\(path)"),
            resolvingAgainstBaseURL: false
        ) else {
            throw URLError(.badURL)
		}
		components.queryItems = queryItems.compactMap(\.self)
		// An unescaped plus is interpreted as a space by URLSearchParams.
		components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
		guard let url = components.url else {
			throw URLError(.badURL)
		}
		return url
	}

	private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
		let (data, _) = try await sendData(request)
		return try decoder.decode(Response.self, from: data)
	}

	/// Validates HTTP responses and preserves API errors for both JSON and empty responses.
	private func sendData(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
		try Task.checkCancellation()
		let (data, response) = try await httpClient.send(request: request)
		try Task.checkCancellation()
		guard let response = response as? HTTPURLResponse else {
			throw URLError(.badServerResponse)
		}
		guard 200..<300 ~= response.statusCode else {
			throw try decoder.decode(APIErrorResponse.self, from: data).error
		}
		return (data, response)
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
