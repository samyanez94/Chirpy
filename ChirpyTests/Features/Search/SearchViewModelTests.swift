//
//  SearchViewModelTests.swift
//  ChirpyTests
//
//  Created by Samuel Yanez on 10/8/26.
//

import Foundation
import Testing

@testable import Chirpy

@MainActor
struct SearchViewModelTests {
	@Test(arguments: ["", " \n\t "])
	func blankQueriesStayIdle(query: String) async {
		let client = SearchClientSpy(results: [])
		let model = SearchViewModel(query: query, client: client)
		await model.load()
		#expect(model.state == .idle)
		#expect(await client.requests.isEmpty)
	}

	@Test func trimsQueryAndDeduplicatesResults() async throws {
		let page = SocialFeedPage(posts: [.preview, .preview], nextCursor: "next")
		let client = SearchClientSpy(results: [.success(page)])
		let model = SearchViewModel(query: "  bottle\n", client: client)
		await model.load()
		await model.load()
		#expect(model.state == .loaded(content: .init(posts: [.preview], nextCursor: "next")))
		#expect(await client.requests == [.init(query: "bottle", cursor: nil, limit: 20)])
	}

	@Test func emptyResultsAreLoadedContent() async {
		let client = SearchClientSpy(results: [.success(.init(posts: [], nextCursor: nil))])
		let model = SearchViewModel(query: "missing", client: client)
		await model.load()
		#expect(model.state == .loaded(content: .init(posts: [], nextCursor: nil)))
	}

	@Test func failedSearchCanBeRetried() async {
		let page = SocialFeedPage(posts: [.preview], nextCursor: nil)
		let client = SearchClientSpy(results: [.failure(URLError(.notConnectedToInternet)), .success(page)])
		let model = SearchViewModel(query: "bottle", client: client)
		await model.load()
		#expect(model.state == .error(message: "Search couldn’t be loaded."))
		await model.retry()
		#expect(model.state == .loaded(content: .init(posts: page.posts, nextCursor: nil)))
	}

	@Test(.timeLimit(.minutes(1)))
	func newerQueryWinsEvenWhenOldTransportIgnoresCancellation() async {
		let client = SearchClientSpy()
		let model = SearchViewModel(query: "old", client: client)
		let oldTask = Task { await model.load() }
		await client.waitForRequests(1)
		#expect(model.state == .loading)

		oldTask.cancel()
		let newModel = SearchViewModel(query: "new", client: client)
		let newTask = Task { await newModel.load() }
		await client.waitForRequests(2)
		await client.complete(1, with: .success(.init(posts: [], nextCursor: nil)))
		await newTask.value
		await client.complete(0, with: .success(.init(posts: [.preview], nextCursor: "old-cursor")))
		await oldTask.value

		#expect(newModel.state == .loaded(content: .init(posts: [], nextCursor: nil)))
		#expect(model.state == .idle)
		#expect(await client.cancelledRequests == [0])
	}

	@Test(.timeLimit(.minutes(1)))
	func clearingQueryCancelsAndDiscardsResults() async {
		let client = SearchClientSpy()
		let model = SearchViewModel(query: "bottle", client: client)
		let task = Task { await model.load() }
		await client.waitForRequests(1)
		task.cancel()
		let clearedModel = SearchViewModel(query: "", client: client)
		await clearedModel.load()
		await client.complete(0, with: .success(.init(posts: [.preview], nextCursor: nil)))
		await task.value
		#expect(model.state == .idle)
		#expect(clearedModel.state == .idle)
		#expect(await client.requests.count == 1)
		#expect(await client.cancelledRequests == [0])
	}

	@Test(.timeLimit(.minutes(1)))
	func callerCancellationIsNotAnError() async {
		let client = SearchClientSpy()
		let model = SearchViewModel(query: "bottle", client: client)
		let task = Task { await model.load() }
		await client.waitForRequests(1)
		task.cancel()
		await client.complete(0, with: .success(.init(posts: [.preview], nextCursor: nil)))
		await task.value
		#expect(model.state == .idle)
		#expect(await client.cancelledRequests == [0])
	}

	@Test func alreadyCancelledSearchDoesNotSendRequest() async {
		let client = SearchClientSpy(results: [])
		let model = SearchViewModel(query: "bottle", client: client)
		let task = Task {
			withUnsafeCurrentTask { $0?.cancel() }
			await model.load()
		}
		await task.value
		#expect(model.state == .idle)
		#expect(await client.requests.isEmpty)
	}

	@Test func paginationAppendsUniquePostsAndStopsAtEnd() async {
		let nextPost = Post.flockPreview[1]
		let client = SearchClientSpy(results: [
			.success(.init(posts: [.preview], nextCursor: "next")),
			.success(.init(posts: [.preview, nextPost, nextPost], nextCursor: nil))
		])
		let model = SearchViewModel(query: "bottle", client: client)
		await model.load()
		await model.loadNextPage()
		await model.loadNextPage()
		#expect(model.state == .loaded(content: .init(posts: [.preview, nextPost], nextCursor: nil)))
		#expect(
			await client.requests == [
				.init(query: "bottle", cursor: nil, limit: 20),
				.init(query: "bottle", cursor: "next", limit: 20)
			]
		)
	}

	@Test func paginationFailurePreservesResultsAndCanRetry() async {
		let page = SocialFeedPage(posts: [.preview], nextCursor: "next")
		let client = SearchClientSpy(results: [
			.success(page), .failure(URLError(.notConnectedToInternet)),
			.success(.init(posts: [], nextCursor: nil))
		])
		let model = SearchViewModel(query: "bottle", client: client)
		await model.load()
		await model.loadNextPage()
		#expect(
			model.state
				== .loaded(
					content: .init(
						posts: [.preview],
						nextCursor: "next",
						paginationError: "More results couldn’t be loaded."
					)
				)
		)
		await model.loadMoreIfNeeded(after: .preview)
		#expect(await client.requests.count == 2)
		await model.loadNextPage()
		#expect(model.state == .loaded(content: .init(posts: [.preview], nextCursor: nil)))
	}

	@Test(.timeLimit(.minutes(1)))
	func duplicatePaginationIsIgnoredAndNewQueryDiscardsOldPage() async {
		let client = SearchClientSpy()
		let model = SearchViewModel(query: "bottle", client: client)
		let first = Task { await model.load() }
		await client.waitForRequests(1)
		await client.complete(0, with: .success(.init(posts: [.preview], nextCursor: "next")))
		await first.value
		let pagination = Task { await model.loadNextPage() }
		await client.waitForRequests(2)
		await model.loadNextPage()
		#expect(await client.requests.count == 2)
		pagination.cancel()
		let newModel = SearchViewModel(query: "new", client: client)
		let search = Task { await newModel.load() }
		await client.waitForRequests(3)
		await client.complete(2, with: .success(.init(posts: [], nextCursor: nil)))
		await search.value
		await client.complete(1, with: .success(.init(posts: Post.flockPreview, nextCursor: nil)))
		await pagination.value
		#expect(newModel.state == .loaded(content: .init(posts: [], nextCursor: nil)))
	}

	@Test func invalidCursorRestartsCurrentSearch() async {
		let client = SearchClientSpy(results: [
			.success(.init(posts: [.preview], nextCursor: "expired")),
			.failure(APIError(code: "invalid_cursor", message: "Expired", requestID: UUID())),
			.success(.init(posts: [], nextCursor: nil))
		])
		let model = SearchViewModel(query: "bottle", client: client)
		await model.load()
		await model.loadNextPage()
		#expect(model.state == .loaded(content: .init(posts: [], nextCursor: nil)))
		#expect(await client.requests.last?.cursor == nil)
	}

	@Test func refreshFailureKeepsLoadedResults() async {
		let page = SocialFeedPage(posts: [.preview], nextCursor: "next")
		let client = SearchClientSpy(results: [
			.success(page), .failure(URLError(.notConnectedToInternet))
		])
		let model = SearchViewModel(query: "bottle", client: client)
		await model.load()
		await model.refresh()
		#expect(model.state == .loaded(content: .init(posts: [.preview], nextCursor: "next")))
	}

	@Test func failedCursorRecoveryKeepsResultsAndOffersRetry() async {
		let client = SearchClientSpy(results: [
			.success(.init(posts: [.preview], nextCursor: "expired")),
			.failure(APIError(code: "invalid_cursor", message: "Expired", requestID: UUID())),
			.failure(URLError(.notConnectedToInternet))
		])
		let model = SearchViewModel(query: "bottle", client: client)
		await model.load()
		await model.loadNextPage()
		#expect(
			model.state
				== .loaded(
					content: .init(
						posts: [.preview],
						nextCursor: "expired",
						paginationError: "More results couldn’t be loaded."
					)
				)
		)
	}

	@Test(.timeLimit(.minutes(1)))
	func paginationPreservesLikesUpdatedWhileLoading() async {
		let client = SearchClientSpy()
		let model = SearchViewModel(query: "bottle", client: client)
		let first = Task { await model.load() }
		await client.waitForRequests(1)
		await client.complete(0, with: .success(.init(posts: [.preview], nextCursor: "next")))
		await first.value

		let pagination = Task { await model.loadNextPage() }
		await client.waitForRequests(2)
		await model.toggleLike(postID: Post.preview.id)
		await client.complete(1, with: .success(.init(posts: [], nextCursor: nil)))
		await pagination.value

		guard case .loaded(let content) = model.state else {
			Issue.record("Expected loaded results")
			return
		}
		#expect(content.posts.first?.isLiked == false)
		#expect(content.posts.first?.likeCount == 11)
		#expect(content.nextCursor == nil)
	}

	@Test func likesUpdateLoadedResults() async {
		let client = SearchClientSpy(results: [.success(.init(posts: [.preview], nextCursor: nil))])
		let model = SearchViewModel(query: "bottle", client: client)
		await model.load()
		await model.toggleLike(postID: Post.preview.id)
		guard case .loaded(let content) = model.state else {
			Issue.record("Expected loaded results")
			return
		}
		#expect(content.posts.first?.isLiked == false)
		#expect(content.posts.first?.likeCount == 11)
	}
}

private actor SearchClientSpy: ChirpyServicing {
	func deletePost(postID: UUID) async throws { throw URLError(.unsupportedURL) }

	func fetchCurrentProfile() async throws -> Profile { throw URLError(.unsupportedURL) }

	struct Request: Equatable, Sendable {
		let query: String
		let cursor: String?
		let limit: Int
	}

	private(set) var requests: [Request] = []
	private(set) var cancelledRequests: [Int] = []
	private var results: [Result<SocialFeedPage, Error>]?
	private var pending: [Int: CheckedContinuation<SocialFeedPage, Error>] = [:]
	private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []

	init(results: [Result<SocialFeedPage, Error>]? = nil) {
		self.results = results
	}

	func searchPosts(query: String, cursor: String?, limit: Int) async throws -> SocialFeedPage {
		let index = requests.count
		requests.append(.init(query: query, cursor: cursor, limit: limit))
		let page = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SocialFeedPage, Error>) in
			if var results {
				if results.isEmpty {
					continuation.resume(throwing: URLError(.badServerResponse))
				} else {
					let result = results.removeFirst()
					self.results = results
					continuation.resume(with: result)
				}
			} else {
				pending[index] = continuation
			}
			let ready = waiters.filter { $0.0 <= requests.count }
			waiters.removeAll { $0.0 <= requests.count }
			for waiter in ready { waiter.1.resume() }
		}
		if Task.isCancelled { cancelledRequests.append(index) }
		return page
	}

	func waitForRequests(_ count: Int) async {
		guard requests.count < count else { return }
		await withCheckedContinuation { waiters.append((count, $0)) }
	}

	func complete(_ index: Int, with result: Result<SocialFeedPage, Error>) {
		pending.removeValue(forKey: index)?.resume(with: result)
	}

	func fetchPage(profileID: UUID?, cursor: String?, limit: Int) async throws -> SocialFeedPage {
		throw URLError(.unsupportedURL)
	}

	func createPost(text: String) async throws -> Post {
		throw URLError(.unsupportedURL)
	}

	func setLike(postID: UUID, isLiked: Bool) async throws -> PostLikeUpdate {
		PostLikeUpdate(postID: postID, isLiked: isLiked, likeCount: 11)
	}
}
