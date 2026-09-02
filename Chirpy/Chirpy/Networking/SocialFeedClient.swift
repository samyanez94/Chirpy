//
//  SocialFeedClient.swift
//  Chirpy
//
//  Created by Samuel Yanez on 8/31/26.
//

import Foundation

// MARK: - SocialFeedServicing

nonisolated protocol SocialFeedServicing: Sendable {
	func fetchPage(
		cursor: String?,
		limit: Int
	) async throws -> SocialFeedPage

	func setLike(
		postID: UUID,
		isLiked: Bool
	) async throws -> PostLikeUpdate
}

// MARK: - SocialFeedClient

nonisolated struct SocialFeedClient: SocialFeedServicing {

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
		var components = URLComponents(
			url: baseURL.appending(path: "functions/v1/social-feed/feed"),
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

		let (data, response) = try await httpClient.send(request: URLRequest(url: url))

		guard let response = response as? HTTPURLResponse else {
			throw URLError(.badServerResponse)
		}

		guard 200..<300 ~= response.statusCode else {
			throw try decoder.decode(APIErrorResponse.self, from: data).error
		}

		return try decoder.decode(SocialFeedPage.self, from: data)
	}

	func setLike(
		postID: UUID,
		isLiked: Bool
	) async throws -> PostLikeUpdate {
		let url = baseURL.appending(
			path: "functions/v1/social-feed/posts/\(postID)/like"
		)

		var request = URLRequest(url: url)
		request.httpMethod = isLiked ? "POST" : "DELETE"

		let (data, response) = try await httpClient.send(request: request)

		guard let response = response as? HTTPURLResponse else {
			throw URLError(.badServerResponse)
		}

		guard 200..<300 ~= response.statusCode else {
			throw try decoder.decode(APIErrorResponse.self, from: data).error
		}

		return try decoder.decode(PostLikeUpdate.self, from: data)
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
