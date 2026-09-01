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
	func testRefreshError() async {
		let initialPage = SocialFeedPage(
			posts: [makePost(1)],
			nextCursor: "next-page"
		)
		let client = SocialFeedServiceSpy(
			results: [.success(initialPage), .failure(.requestFailed)]
		)
		let viewModel = FeedViewModel(client: client)

		await viewModel.load()
		let stateBeforeRefresh = viewModel.state
		await viewModel.refresh()

		#expect(viewModel.state == stateBeforeRefresh)
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
}

private actor SocialFeedServiceSpy: SocialFeedServicing {
	private var results: [Result<SocialFeedPage, TestError>]
	private var requests: [SocialFeedRequest] = []

	init(results: [Result<SocialFeedPage, TestError>]) {
		self.results = results
	}

	func fetchPage(cursor: String?, limit: Int) async throws -> SocialFeedPage {
		requests.append(SocialFeedRequest(cursor: cursor, limit: limit))

		guard results.isEmpty == false else {
			throw TestError.missingResult
		}

		return try results.removeFirst().get()
	}

	func recordedRequests() -> [SocialFeedRequest] {
		requests
	}
}

private nonisolated struct SocialFeedRequest: Equatable, Sendable {
	let cursor: String?
	let limit: Int
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
