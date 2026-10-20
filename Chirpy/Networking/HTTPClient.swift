//
//  HTTPClient.swift
//  Chirpy
//
//  Created by Samuel Yanez on 8/31/26.
//

import Foundation

// MARK: - HTTPClient

nonisolated protocol HTTPClient: Sendable {
	func send(request: URLRequest) async throws -> (Data, URLResponse)
}

// MARK: - URLSessionHTTPClient

nonisolated struct URLSessionHTTPClient: HTTPClient {
	private let session: URLSession

	init(session: URLSession = .shared) {
		self.session = session
	}

	func send(request: URLRequest) async throws -> (Data, URLResponse) {
		try await session.data(for: request)
	}
}
