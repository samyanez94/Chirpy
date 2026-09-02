import Foundation
import Testing

@testable import Chirpy

@MainActor
struct FeedViewModelTests {
	@Test
	func testLoad() async {
		let page = SocialFeedPage(posts: [makePost(1)], nextCursor: "next-page")
		let viewModel = FeedViewModel(
			client: SocialFeedServiceSpy(results: [.success(page)])
		)

		await viewModel.load()

		#expect(
			viewModel.state
				== .loaded(
					content: FeedViewModel.FeedContent(
						posts: page.posts,
						nextCursor: page.nextCursor
					)
				)
		)
	}

	@Test
	func testLoadError() async {
		let viewModel = FeedViewModel(
			client: SocialFeedServiceSpy(results: [.failure(.requestFailed)])
		)

		await viewModel.load()

		#expect(
			viewModel.state
				== .error(
					message: "The feed couldn’t be loaded."
				)
		)
	}

	@Test
	func testRefresh() async {
		let initialPage = SocialFeedPage(
			posts: [makePost(1)],
			nextCursor: "old-cursor"
		)
		let refreshedPage = SocialFeedPage(
			posts: [makePost(2)],
			nextCursor: "new-cursor"
		)
		let client = SocialFeedServiceSpy(
			results: [.success(initialPage), .success(refreshedPage)]
		)
		let viewModel = FeedViewModel(client: client)

		await viewModel.load()
		await viewModel.refresh()

		#expect(
			viewModel.state
				== .loaded(
					content: FeedViewModel.FeedContent(
						posts: refreshedPage.posts,
						nextCursor: refreshedPage.nextCursor
					)
				)
		)
		let requests = await client.recordedRequests()
		#expect(
			requests == [
				SocialFeedRequest(cursor: nil, limit: 20),
				SocialFeedRequest(cursor: nil, limit: 20)
			]
		)
	}

	@Test
	func testRefreshErrorKeepsPostsAndMarksThemStale() async {
		let initialPage = SocialFeedPage(
			posts: [makePost(1)],
			nextCursor: "next-page"
		)
		let client = SocialFeedServiceSpy(
			results: [.success(initialPage), .failure(.requestFailed)]
		)
		let viewModel = FeedViewModel(client: client)

		await viewModel.load()
		await viewModel.refresh()

		#expect(loadedContent(viewModel)?.posts == initialPage.posts)
		#expect(loadedContent(viewModel)?.nextCursor == initialPage.nextCursor)
		#expect(staleReason(viewModel) == .failed)
	}

	@Test
	func testRefreshWhileOfflineReportsAConnectivityProblem() async {
		let client = SocialFeedServiceSpy(
			results: [
				.success(SocialFeedPage(posts: [makePost(1)], nextCursor: nil)),
				.failure(.offline)
			]
		)
		let viewModel = FeedViewModel(client: client)

		await viewModel.load()
		await viewModel.refresh()

		#expect(staleReason(viewModel) == .offline)
	}

	/// A server-side failure should not be reported as the reader being offline.
	@Test
	func testLoadFromCacheWhileOfflineReportsAConnectivityProblem() async {
		let cachedPage = SocialFeedPage(posts: [makePost(1)], nextCursor: nil)
		let viewModel = FeedViewModel(
			client: SocialFeedServiceSpy(results: [.failure(.offline)]),
			snapshotStore: FeedSnapshotStoreSpy(
				snapshot: FeedSnapshot(
					page: cachedPage,
					savedAt: Date(timeIntervalSince1970: 1_000)
				)
			)
		)

		await viewModel.load()

		#expect(staleReason(viewModel) == .offline)
		#expect(loadedContent(viewModel)?.posts == cachedPage.posts)
	}

	@Test
	func testFirstPageRequestStateIsNotLeftSet() async {
		let client = SocialFeedServiceSpy(
			results: [
				.success(SocialFeedPage(posts: [makePost(1)], nextCursor: nil)),
				.failure(.requestFailed)
			]
		)
		let viewModel = FeedViewModel(client: client)

		await viewModel.load()
		#expect(viewModel.isFetchingFirstPage == false)

		await viewModel.refresh()
		#expect(viewModel.isFetchingFirstPage == false)
	}

	@Test
	func testRefreshAfterFailureClearsStaleness() async {
		let initialPage = SocialFeedPage(
			posts: [makePost(1)],
			nextCursor: "next-page"
		)
		let refreshedPage = SocialFeedPage(
			posts: [makePost(2)],
			nextCursor: "new-cursor"
		)
		let client = SocialFeedServiceSpy(
			results: [
				.success(initialPage),
				.failure(.requestFailed),
				.success(refreshedPage)
			]
		)
		let viewModel = FeedViewModel(client: client)

		await viewModel.load()
		await viewModel.refresh()
		await viewModel.refresh()

		#expect(
			viewModel.state
				== .loaded(
					content: FeedViewModel.FeedContent(
						posts: refreshedPage.posts,
						nextCursor: refreshedPage.nextCursor
					)
				)
		)
	}

	@Test
	func testLoadFallsBackToCachedPostsWhenRequestFails() async {
		let cachedPage = SocialFeedPage(
			posts: [makePost(1)],
			nextCursor: "cached-cursor"
		)
		let savedAt = Date(timeIntervalSince1970: 1_000)
		let viewModel = FeedViewModel(
			client: SocialFeedServiceSpy(results: [.failure(.requestFailed)]),
			snapshotStore: FeedSnapshotStoreSpy(
				snapshot: FeedSnapshot(page: cachedPage, savedAt: savedAt)
			)
		)

		await viewModel.load()

		#expect(
			viewModel.state
				== .loaded(
					content: FeedViewModel.FeedContent(
						posts: cachedPage.posts,
						nextCursor: cachedPage.nextCursor,
						freshness: .stale(updatedAt: savedAt, reason: .failed)
					)
				)
		)
	}

	@Test
	func testCancelledLoadDoesNotMarkCachedPostsStale() async {
		let cachedPage = SocialFeedPage(
			posts: [makePost(1)],
			nextCursor: "cached-cursor"
		)
		let viewModel = FeedViewModel(
			client: SocialFeedServiceSpy(results: []),
			snapshotStore: FeedSnapshotStoreSpy(
				snapshot: FeedSnapshot(
					page: cachedPage,
					savedAt: Date(timeIntervalSince1970: 1_000)
				)
			)
		)

		let load = Task { await viewModel.load() }
		load.cancel()
		await load.value

		#expect(
			viewModel.state
				== .loaded(
					content: FeedViewModel.FeedContent(
						posts: cachedPage.posts,
						nextCursor: cachedPage.nextCursor,
						freshness: .current
					)
				)
		)
	}

	@Test
	func testLoadSavesSnapshotOfFirstPage() async {
		let page = SocialFeedPage(posts: [makePost(1)], nextCursor: "next-page")
		let store = FeedSnapshotStoreSpy()
		let viewModel = FeedViewModel(
			client: SocialFeedServiceSpy(results: [.success(page)]),
			snapshotStore: store
		)

		await viewModel.load()

		#expect(await store.recordedSaves().map(\.page) == [page])
	}

	@Test
	func testLoadNextPage() async {
		let firstPost = makePost(1)
		let secondPost = makePost(2)
		let firstPage = SocialFeedPage(
			posts: [firstPost],
			nextCursor: "page-two"
		)
		let secondPage = SocialFeedPage(
			posts: [secondPost],
			nextCursor: nil
		)
		let client = SocialFeedServiceSpy(
			results: [.success(firstPage), .success(secondPage)]
		)
		let viewModel = FeedViewModel(client: client)

		await viewModel.load()
		await viewModel.loadNextPage()

		#expect(
			viewModel.state
				== .loaded(
					content: FeedViewModel.FeedContent(
						posts: [firstPost, secondPost],
						nextCursor: nil
					)
				)
		)
		let requests = await client.recordedRequests()
		#expect(requests.last == SocialFeedRequest(cursor: "page-two", limit: 20))
	}

	@Test
	func testLoadNextPageError() async {
		let firstPost = makePost(1)
		let firstPage = SocialFeedPage(
			posts: [firstPost],
			nextCursor: "page-two"
		)
		let client = SocialFeedServiceSpy(
			results: [.success(firstPage), .failure(.requestFailed)]
		)
		let viewModel = FeedViewModel(client: client)

		await viewModel.load()
		await viewModel.loadNextPage()

		#expect(
			viewModel.state
				== .loaded(
					content: FeedViewModel.FeedContent(
						posts: [firstPost],
						nextCursor: "page-two",
						paginationState: .error(
							message: "More posts couldn’t be loaded."
						)
					)
				)
		)
	}

	@Test
	func testLoadMoreIfNeeded() async {
		let initialPosts = (1...6).map { makePost(UInt8($0)) }
		let nextPost = makePost(7)
		let firstPage = SocialFeedPage(
			posts: initialPosts,
			nextCursor: "page-two"
		)
		let secondPage = SocialFeedPage(
			posts: [nextPost],
			nextCursor: nil
		)
		let client = SocialFeedServiceSpy(
			results: [.success(firstPage), .success(secondPage)]
		)
		let viewModel = FeedViewModel(client: client)

		await viewModel.load()
		await viewModel.loadMoreIfNeeded(after: initialPosts[0])

		let requestsBeforeThreshold = await client.recordedRequests()
		#expect(requestsBeforeThreshold.count == 1)

		await viewModel.loadMoreIfNeeded(after: initialPosts[1])

		let requestsAfterThreshold = await client.recordedRequests()
		#expect(
			requestsAfterThreshold == [
				SocialFeedRequest(cursor: nil, limit: 20),
				SocialFeedRequest(cursor: "page-two", limit: 20)
			]
		)
	}

	@Test
	func testToggleLike() async {
		let post = makePost(1)
		let page = SocialFeedPage(posts: [post], nextCursor: nil)
		let update = PostLikeUpdate(
			postID: post.id,
			isLiked: true,
			likeCount: 2
		)
		let client = SocialFeedServiceSpy(
			results: [.success(page)],
			likeResults: [.success(update)]
		)
		let viewModel = FeedViewModel(client: client)

		await viewModel.load()
		await viewModel.toggleLike(postID: post.id)

		var likedPost = post
		likedPost.isLiked = true
		likedPost.likeCount = 2
		#expect(
			viewModel.state
				== .loaded(
					content: FeedViewModel.FeedContent(
						posts: [likedPost],
						nextCursor: nil
					)
				)
		)
		let likeRequests = await client.recordedLikeRequests()
		#expect(
			likeRequests == [
				SocialFeedLikeRequest(postID: post.id, isLiked: true)
			]
		)
	}
}

@MainActor
private func loadedContent(
	_ viewModel: FeedViewModel
) -> FeedViewModel.FeedContent? {
	guard case .loaded(let content) = viewModel.state else {
		return nil
	}
	return content
}

@MainActor
private func staleReason(
	_ viewModel: FeedViewModel
) -> FeedViewModel.StaleReason? {
	guard case .stale(_, let reason) = loadedContent(viewModel)?.freshness else {
		return nil
	}
	return reason
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
			throw error.thrown
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

private nonisolated enum TestError: Error, Sendable {
	case missingResult
	case requestFailed
	case offline

	/// The error the spy actually throws.
	///
	/// Connectivity classification keys off `URLError`, so the offline case has
	/// to surface as one rather than as a bespoke test error.
	var thrown: any Error {
		switch self {
		case .offline:
			URLError(.notConnectedToInternet)
		default:
			self
		}
	}
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
