import Foundation

nonisolated struct FeedRepository: FeedRepositoryProtocol {
	private let client: any SocialFeedServicing

	init(client: any SocialFeedServicing) {
		self.client = client
	}

	func fetchPage(limit: Int, cursor: String?) async throws -> SocialFeedPage {
		try Task.checkCancellation()
		let page = try await client.fetchPage(cursor: cursor, limit: limit)
		try Task.checkCancellation()
		return page
	}

	func setLike(postID: UUID, isLiked: Bool) async throws -> PostLikeUpdate {
		try await client.setLike(postID: postID, isLiked: isLiked)
	}
}
