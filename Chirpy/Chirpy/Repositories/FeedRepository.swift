import Foundation

/// Coordinates remote feed access and best-effort first-page persistence.
nonisolated struct FeedRepository: FeedRepositoryProtocol {
	private let client: any SocialFeedServicing

	private let snapshotStore: any FeedSnapshotStoring

	init(client: any SocialFeedServicing, snapshotStore: any FeedSnapshotStoring) {
		self.client = client
		self.snapshotStore = snapshotStore
	}

	func pages(limit: Int, cursor: String?) -> AsyncThrowingStream<SocialFeedPage, Error> {
		let (stream, continuation) = AsyncThrowingStream<SocialFeedPage, Error>
			.makeStream(bufferingPolicy: .bufferingOldest(2))

		let producer = Task {
			do {
				if cursor == nil,
					let snapshot = await snapshotStore.loadSnapshot(),
					snapshot.limit == limit
				{
					continuation.yield(snapshot.page)
				}
				let page = try await fetchPage(limit: limit, cursor: cursor)
				continuation.yield(page)
				continuation.finish()
			} catch {
				continuation.finish(throwing: error)
			}
		}

		continuation.onTermination = { @Sendable _ in
			producer.cancel()
		}
		return stream
	}

	func fetchPage(limit: Int, cursor: String?) async throws -> SocialFeedPage {
		try Task.checkCancellation()
		let page = try await client.fetchPage(cursor: cursor, limit: limit)
		try Task.checkCancellation()
		if cursor == nil {
			await snapshotStore.save(snapshot: FeedSnapshot(page: page, limit: limit))
		}
		return page
	}

	func setLike(postID: UUID, isLiked: Bool) async throws -> PostLikeUpdate {
		try await client.setLike(postID: postID, isLiked: isLiked)
	}
}
