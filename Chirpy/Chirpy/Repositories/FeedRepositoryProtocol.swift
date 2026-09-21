import Foundation

/// Provides feed data without exposing networking or snapshot persistence.
nonisolated protocol FeedRepositoryProtocol: Sendable {
	/// Emits a matching cached first page when available, then a fresh page.
	/// Requests with a cursor emit only a fresh page. Each call starts a finite
	/// load immediately; cancelling iteration cancels the underlying request.
	func pages(limit: Int, cursor: String?) -> AsyncThrowingStream<SocialFeedPage, Error>

	/// Fetches a fresh page, replacing the snapshot only when cursor is nil.
	func fetchPage(limit: Int, cursor: String?) async throws -> SocialFeedPage

	/// Returns the server-authoritative like state without changing the snapshot.
	func setLike(postID: UUID, isLiked: Bool) async throws -> PostLikeUpdate
}
