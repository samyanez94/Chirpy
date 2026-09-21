import Foundation

/// Provides feed data without exposing networking details.
nonisolated protocol FeedRepositoryProtocol: Sendable {
	func fetchPage(limit: Int, cursor: String?) async throws -> SocialFeedPage

	/// Returns the server-authoritative like state.
	func setLike(postID: UUID, isLiked: Bool) async throws -> PostLikeUpdate
}
