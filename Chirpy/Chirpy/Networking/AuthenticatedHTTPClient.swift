import Foundation

/// Adds the personal backend key without changing request or retry behavior.
nonisolated struct AuthenticatedHTTPClient: HTTPClient {
	private let apiKey: String?
	private let transport: any HTTPClient

	init(apiKey: String?, transport: any HTTPClient = URLSessionHTTPClient()) {
		self.apiKey = apiKey
		self.transport = transport
	}

	func send(request: URLRequest) async throws -> (Data, URLResponse) {
		guard let apiKey, !apiKey.isEmpty else { throw URLError(.userAuthenticationRequired) }
		var request = request
		request.setValue(apiKey, forHTTPHeaderField: "X-Chirpy-API-Key")
		return try await transport.send(request: request)
	}
}
