import Foundation
import Testing

@testable import Chirpy

struct FeedRepositoryTests {
	@Test(arguments: [true, false])
	func streamEmitsCacheThenFreshPage(hasCache: Bool) async throws {
		let cached = SocialFeedPage(posts: [makePost(1)], nextCursor: "cached")
		let fresh = SocialFeedPage(posts: [makePost(2)], nextCursor: "fresh")
		let store = FeedSnapshotStoreSpy(
			snapshot: hasCache ? FeedSnapshot(page: cached, limit: 20) : nil
		)
		let client = SocialFeedServiceSpy(results: [.success(fresh)])
		let repository = FeedRepository(client: client, snapshotStore: store)
		var pages: [SocialFeedPage] = []

		for try await page in repository.pages(limit: 20, cursor: nil) {
			pages.append(page)
		}

		#expect(pages == (hasCache ? [cached, fresh] : [fresh]))
		#expect(await store.recordedSaves().map(\.page) == [fresh])
		#expect(await client.recordedRequests() == [SocialFeedRequest(cursor: nil, limit: 20)])
	}

	@Test(arguments: [true, false])
	func streamPropagatesFailureAfterAnyCachedPage(hasCache: Bool) async {
		let cached = SocialFeedPage(posts: [makePost(1)], nextCursor: "cached")
		let store = FeedSnapshotStoreSpy(
			snapshot: hasCache ? FeedSnapshot(page: cached, limit: 20) : nil
		)
		let repository = FeedRepository(
			client: SocialFeedServiceSpy(results: [.failure(.requestFailed)]),
			snapshotStore: store
		)
		var pages: [SocialFeedPage] = []

		await #expect(throws: TestError.requestFailed) {
			for try await page in repository.pages(limit: 20, cursor: nil) {
				pages.append(page)
			}
		}

		#expect(pages == (hasCache ? [cached] : []))
		#expect(await store.recordedSaves().isEmpty)
	}

	@Test
	func mismatchedLimitSkipsCacheAndReplacesSnapshot() async throws {
		let cached = SocialFeedPage(posts: [makePost(1)], nextCursor: "cached")
		let fresh = SocialFeedPage(posts: [makePost(2)], nextCursor: "fresh")
		let store = FeedSnapshotStoreSpy(snapshot: FeedSnapshot(page: cached, limit: 20))
		let client = SocialFeedServiceSpy(results: [.success(fresh)])
		let repository = FeedRepository(client: client, snapshotStore: store)
		var pages: [SocialFeedPage] = []

		for try await page in repository.pages(limit: 50, cursor: nil) {
			pages.append(page)
		}

		#expect(pages == [fresh])
		#expect(await client.recordedRequests() == [SocialFeedRequest(cursor: nil, limit: 50)])
		let snapshot = try #require(await store.loadSnapshot())
		#expect(snapshot.page == fresh)
		#expect(snapshot.limit == 50)
	}

	@Test
	func cursorStreamSkipsCacheAndPreservesSnapshot() async throws {
		let cached = SocialFeedPage(posts: [makePost(1)], nextCursor: "next")
		let next = SocialFeedPage(posts: [makePost(2)], nextCursor: nil)
		let snapshot = FeedSnapshot(page: cached, limit: 50)
		let store = FeedSnapshotStoreSpy(snapshot: snapshot)
		let client = SocialFeedServiceSpy(results: [.success(next)])
		let repository = FeedRepository(client: client, snapshotStore: store)
		var pages: [SocialFeedPage] = []

		for try await page in repository.pages(limit: 50, cursor: "next") {
			pages.append(page)
		}

		#expect(pages == [next])
		#expect(await client.recordedRequests() == [SocialFeedRequest(cursor: "next", limit: 50)])
		#expect(await store.recordedSaves().isEmpty)
		#expect(await store.loadSnapshot() == snapshot)
	}

	@Test(.timeLimit(.minutes(1)))
	func cachedPageIsDeliveredWhileFetchingAndCancellationStopsRequest() async throws {
		let cached = SocialFeedPage(posts: [makePost(1)], nextCursor: "cached")
		let store = FeedSnapshotStoreSpy(snapshot: FeedSnapshot(page: cached, limit: 20))
		let (started, startedContinuation) = AsyncStream<Void>.makeStream()
		let (cancelled, cancelledContinuation) = AsyncStream<Void>.makeStream()
		let client = SuspendedFeedClient(started: startedContinuation, cancelled: cancelledContinuation)
		let repository = FeedRepository(client: client, snapshotStore: store)
		let (received, receivedContinuation) = AsyncStream<SocialFeedPage>.makeStream()
		let consumer = Task {
			defer { receivedContinuation.finish() }
			for try await page in repository.pages(limit: 20, cursor: nil) {
				receivedContinuation.yield(page)
			}
		}
		defer { consumer.cancel() }

		var startedIterator = started.makeAsyncIterator()
		#expect(await startedIterator.next() != nil)
		var receivedIterator = received.makeAsyncIterator()
		#expect(await receivedIterator.next() == cached)

		consumer.cancel()
		var cancelledIterator = cancelled.makeAsyncIterator()
		#expect(await cancelledIterator.next() != nil)
		_ = await consumer.result

		#expect(await store.recordedSaves().isEmpty)
		#expect(await store.loadSnapshot()?.page == cached)
	}

	@Test
	func firstPageFetchReplacesSnapshot() async throws {
		let cached = SocialFeedPage(posts: [makePost(1)], nextCursor: "old")
		let fresh = SocialFeedPage(posts: [makePost(2)], nextCursor: "new")
		let client = SocialFeedServiceSpy(results: [.success(fresh)])
		let store = FeedSnapshotStoreSpy(snapshot: FeedSnapshot(page: cached, limit: 20))
		let repository = FeedRepository(client: client, snapshotStore: store)

		let page = try await repository.fetchPage(limit: 35, cursor: nil)

		#expect(page == fresh)
		#expect(await store.loadSnapshot()?.limit == 35)
		#expect(await store.loadSnapshot()?.page == fresh)
		#expect(await store.recordedSaves().map(\.page) == [fresh])
		#expect(await client.recordedRequests() == [SocialFeedRequest(cursor: nil, limit: 35)])
	}

	@Test
	func failedFirstPageFetchPreservesSnapshot() async {
		let cached = SocialFeedPage(posts: [makePost(1)], nextCursor: "cached")
		let store = FeedSnapshotStoreSpy(snapshot: FeedSnapshot(page: cached, limit: 20))
		let repository = FeedRepository(
			client: SocialFeedServiceSpy(results: [.failure(.requestFailed)]),
			snapshotStore: store
		)

		await #expect(throws: TestError.requestFailed) {
			try await repository.fetchPage(limit: 20, cursor: nil)
		}

		#expect(await store.loadSnapshot()?.page == cached)
		#expect(await store.recordedSaves().isEmpty)
	}

	@Test
	func cancelledFirstPageFetchPreservesSnapshot() async {
		let cached = SocialFeedPage(posts: [makePost(1)], nextCursor: "cached")
		let store = FeedSnapshotStoreSpy(snapshot: FeedSnapshot(page: cached, limit: 20))
		let repository = FeedRepository(
			client: SocialFeedServiceSpy(results: []),
			snapshotStore: store
		)
		let fetch = Task {
			withUnsafeCurrentTask { $0?.cancel() }
			await #expect(throws: CancellationError.self) {
				try await repository.fetchPage(limit: 20, cursor: nil)
			}
		}
		await fetch.value

		#expect(await store.loadSnapshot()?.page == cached)
		#expect(await store.recordedSaves().isEmpty)
	}

	@Test
	func nextPageDoesNotReplaceSnapshot() async throws {
		let first = SocialFeedPage(posts: [makePost(1)], nextCursor: "next")
		let next = SocialFeedPage(posts: [makePost(2)], nextCursor: nil)
		let client = SocialFeedServiceSpy(results: [.success(next)])
		let store = FeedSnapshotStoreSpy(snapshot: FeedSnapshot(page: first, limit: 20))
		let repository = FeedRepository(client: client, snapshotStore: store)

		#expect(try await repository.fetchPage(limit: 20, cursor: "next") == next)
		#expect(await client.recordedRequests() == [SocialFeedRequest(cursor: "next", limit: 20)])
		#expect(await store.loadSnapshot()?.page == first)
		#expect(await store.recordedSaves().isEmpty)
	}

	@Test(arguments: [true, false])
	func likeUpdateDoesNotChangeSnapshot(isLiked: Bool) async throws {
		let post = makePost(1)
		let page = SocialFeedPage(posts: [post], nextCursor: nil)
		let update = PostLikeUpdate(postID: post.id, isLiked: isLiked, likeCount: 42)
		let client = SocialFeedServiceSpy(results: [], likeResults: [.success(update)])
		let store = FeedSnapshotStoreSpy(snapshot: FeedSnapshot(page: page, limit: 20))
		let repository = FeedRepository(client: client, snapshotStore: store)

		#expect(try await repository.setLike(postID: post.id, isLiked: isLiked) == update)
		#expect(
			await client.recordedLikeRequests() == [
				SocialFeedLikeRequest(postID: post.id, isLiked: isLiked)
			]
		)
		#expect(await store.loadSnapshot()?.page == page)
		#expect(await store.recordedSaves().isEmpty)
	}
}

private actor FeedSnapshotStoreSpy: FeedSnapshotStoring {
	private var snapshot: FeedSnapshot?
	private var saves: [FeedSnapshot] = []

	init(snapshot: FeedSnapshot? = nil) {
		self.snapshot = snapshot
	}

	func loadSnapshot() async -> FeedSnapshot? {
		snapshot
	}

	func save(snapshot: FeedSnapshot) async {
		self.snapshot = snapshot
		saves.append(snapshot)
	}

	func removeSnapshot() async {
		snapshot = nil
	}

	func recordedSaves() -> [FeedSnapshot] {
		saves
	}
}

private actor SocialFeedServiceSpy: SocialFeedServicing {
	private var results: [Result<SocialFeedPage, TestError>]
	private var likeResults: [Result<PostLikeUpdate, TestError>]
	private var requests: [SocialFeedRequest] = []
	private var likeRequests: [SocialFeedLikeRequest] = []

	init(
		results: [Result<SocialFeedPage, TestError>],
		likeResults: [Result<PostLikeUpdate, TestError>] = []
	) {
		self.results = results
		self.likeResults = likeResults
	}

	func fetchPage(cursor: String?, limit: Int) async throws -> SocialFeedPage {
		try Task.checkCancellation()
		requests.append(SocialFeedRequest(cursor: cursor, limit: limit))

		guard results.isEmpty == false else {
			throw TestError.missingResult
		}

		switch results.removeFirst() {
		case .success(let page):
			return page
		case .failure(let error):
			throw error
		}
	}

	func setLike(postID: UUID, isLiked: Bool) async throws -> PostLikeUpdate {
		likeRequests.append(
			SocialFeedLikeRequest(postID: postID, isLiked: isLiked)
		)

		guard likeResults.isEmpty == false else {
			throw TestError.missingResult
		}

		return try likeResults.removeFirst().get()
	}

	func recordedRequests() -> [SocialFeedRequest] {
		requests
	}

	func recordedLikeRequests() -> [SocialFeedLikeRequest] {
		likeRequests
	}
}

private nonisolated struct SocialFeedRequest: Equatable, Sendable {
	let cursor: String?
	let limit: Int
}

private nonisolated struct SocialFeedLikeRequest: Equatable, Sendable {
	let postID: UUID
	let isLiked: Bool
}

private nonisolated enum TestError: Error, Equatable, Sendable {
	case missingResult
	case requestFailed
}

private nonisolated func makePost(_ id: UInt8) -> Post {
	Post(
		id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, id)),
		author: Author(
			id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, id)),
			username: "bird\(id)",
			displayName: "Bird \(id)",
			avatarURL: nil
		),
		text: "Post \(id)",
		imageURL: nil,
		createdAt: Date(timeIntervalSince1970: TimeInterval(id)),
		isLiked: false,
		likeCount: Int(id)
	)
}

private nonisolated struct SuspendedFeedClient: SocialFeedServicing {
	let started: AsyncStream<Void>.Continuation
	let cancelled: AsyncStream<Void>.Continuation

	func fetchPage(cursor: String?, limit: Int) async throws -> SocialFeedPage {
		started.yield(())
		started.finish()
		do {
			// This request remains suspended until the consumer cancels it.
			try await Task.sleep(for: .seconds(120))
			throw TestError.requestFailed
		} catch {
			if Task.isCancelled {
				cancelled.yield(())
			}
			cancelled.finish()
			throw error
		}
	}

	func setLike(postID: UUID, isLiked: Bool) async throws -> PostLikeUpdate {
		throw TestError.missingResult
	}
}
