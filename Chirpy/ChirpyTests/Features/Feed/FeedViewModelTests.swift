import Foundation
import Testing

@testable import Chirpy

@MainActor
struct FeedViewModelTests {
	@Test
	func testLoad() async {
		let page = SocialFeedPage(posts: [makePost(1)], nextCursor: "next-page")
		let viewModel = FeedViewModel(
			repository: FeedRepositorySpy(results: [.success(page)])
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
			repository: FeedRepositorySpy(results: [.failure(.requestFailed)])
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
		let repository = FeedRepositorySpy(
			results: [.success(initialPage), .success(refreshedPage)]
		)
		let viewModel = FeedViewModel(repository: repository)

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
		let requests = await repository.recordedRequests()
		#expect(
			requests == [
				FeedRequest(limit: 20, cursor: nil),
				FeedRequest(limit: 20, cursor: nil)
			]
		)
	}

	@Test
	func testRefreshErrorKeepsPosts() async {
		let initialPage = SocialFeedPage(
			posts: [makePost(1)],
			nextCursor: "next-page"
		)
		let repository = FeedRepositorySpy(
			results: [.success(initialPage), .failure(.requestFailed)]
		)
		let viewModel = FeedViewModel(repository: repository)

		await viewModel.load()
		await viewModel.refresh()

		#expect(loadedContent(viewModel)?.posts == initialPage.posts)
		#expect(loadedContent(viewModel)?.nextCursor == initialPage.nextCursor)
	}

	@Test
	func testRefreshAfterFailureCanSucceed() async {
		let initialPage = SocialFeedPage(
			posts: [makePost(1)],
			nextCursor: "next-page"
		)
		let refreshedPage = SocialFeedPage(
			posts: [makePost(2)],
			nextCursor: "new-cursor"
		)
		let repository = FeedRepositorySpy(
			results: [
				.success(initialPage),
				.failure(.requestFailed),
				.success(refreshedPage)
			]
		)
		let viewModel = FeedViewModel(repository: repository)

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
	func testRetryAfterLoadFailure() async {
		let page = SocialFeedPage(posts: [makePost(1)], nextCursor: "next")
		let viewModel = FeedViewModel(
			repository: FeedRepositorySpy(
				results: [.failure(.requestFailed), .success(page)]
			)
		)

		await viewModel.load()
		await viewModel.retry()

		#expect(loadedContent(viewModel)?.posts == page.posts)
		#expect(loadedContent(viewModel)?.nextCursor == page.nextCursor)
	}

	@Test
	func testCancelledLoadWithoutPostsReturnsToIdle() async {
		let viewModel = FeedViewModel(repository: FeedRepositorySpy(results: []))
		let load = Task { await viewModel.load() }
		load.cancel()
		await load.value

		#expect(viewModel.state == .idle)
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
		let repository = FeedRepositorySpy(
			results: [.success(firstPage), .success(secondPage)]
		)
		let viewModel = FeedViewModel(repository: repository)

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
		let requests = await repository.recordedRequests()
		#expect(requests.last == FeedRequest(limit: 20, cursor: "page-two"))
	}

	@Test
	func testLoadNextPageError() async {
		let firstPost = makePost(1)
		let firstPage = SocialFeedPage(
			posts: [firstPost],
			nextCursor: "page-two"
		)
		let repository = FeedRepositorySpy(
			results: [.success(firstPage), .failure(.requestFailed)]
		)
		let viewModel = FeedViewModel(repository: repository)

		await viewModel.load()
		await viewModel.loadNextPage()

		#expect(
			viewModel.state
				== .loaded(
					content: FeedViewModel.FeedContent(
						posts: [firstPost],
						nextCursor: "page-two"
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
		let repository = FeedRepositorySpy(
			results: [.success(firstPage), .success(secondPage)]
		)
		let viewModel = FeedViewModel(repository: repository)

		await viewModel.load()
		await viewModel.loadMoreIfNeeded(after: initialPosts[0])

		let requestsBeforeThreshold = await repository.recordedRequests()
		#expect(requestsBeforeThreshold.count == 1)

		await viewModel.loadMoreIfNeeded(after: initialPosts[1])

		let requestsAfterThreshold = await repository.recordedRequests()
		#expect(
			requestsAfterThreshold == [
				FeedRequest(limit: 20, cursor: nil),
				FeedRequest(limit: 20, cursor: "page-two")
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
		let repository = FeedRepositorySpy(
			results: [.success(page)],
			likeResults: [.success(update)]
		)
		let viewModel = FeedViewModel(repository: repository)

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
		let likeRequests = await repository.recordedLikeRequests()
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

private actor FeedRepositorySpy: FeedRepositoryProtocol {
	private var results: [Result<SocialFeedPage, TestError>]
	private var likeResults: [Result<PostLikeUpdate, TestError>]
	private var requests: [FeedRequest] = []
	private var likeRequests: [SocialFeedLikeRequest] = []

	init(
		results: [Result<SocialFeedPage, TestError>],
		likeResults: [Result<PostLikeUpdate, TestError>] = []
	) {
		self.results = results
		self.likeResults = likeResults
	}

	func fetchPage(limit: Int, cursor: String?) async throws -> SocialFeedPage {
		try fetchPage(request: FeedRequest(limit: limit, cursor: cursor))
	}

	private func fetchPage(request: FeedRequest) throws -> SocialFeedPage {
		try Task.checkCancellation()
		requests.append(request)

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

	func recordedRequests() -> [FeedRequest] {
		requests
	}

	func recordedLikeRequests() -> [SocialFeedLikeRequest] {
		likeRequests
	}
}

private nonisolated struct FeedRequest: Equatable, Sendable {
	let limit: Int
	let cursor: String?
}

private nonisolated struct SocialFeedLikeRequest: Equatable, Sendable {
	let postID: UUID
	let isLiked: Bool
}

private nonisolated enum TestError: Error, Sendable {
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
