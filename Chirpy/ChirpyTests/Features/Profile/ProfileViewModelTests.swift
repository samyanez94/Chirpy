//
//  ProfileViewModelTests.swift
//  ChirpyTests
//
//  Created by Samuel Yanez on 10/9/26.
//

import Foundation
import Testing

@testable import Chirpy

@MainActor
struct ProfileViewModelTests {
	@Test func loadsFilteredPostsWithoutFetchingProfileAndDeduplicates() async {
		let profile = Post.preview.author
		let client = ProfileClientStub(profile: profile, pages: [.success(.init(posts: [.preview, .preview], nextCursor: "next"))])
		let model = ProfileViewModel(client: client, profileID: Post.preview.author.id)
		await model.load()
		await model.load()
		#expect(model.postsState == .loaded(.init(posts: [.preview], nextCursor: "next")))
		#expect(await client.calls == [.posts(profile.id, nil, 20)])
	}

	@Test(.timeLimit(.minutes(1)))
	func cancelledPostsCanResume() async {
		let profile = Post.preview.author
		let client = ProfileClientStub(profile: profile)
		let model = ProfileViewModel(client: client, profileID: Post.preview.author.id)
		let load = Task { await model.load() }
		await client.waitForPage()
		#expect(model.postsState == .loading)
		await model.load()
		#expect(await client.calls.count == 1)
		load.cancel()
		await client.completePage(.success(.init(posts: [.preview], nextCursor: nil)))
		await load.value
		#expect(model.postsState == .idle)
		await client.setPages([.success(.init(posts: [], nextCursor: nil))])
		await model.load()
		#expect(model.postsState == .loaded(.init(posts: [], nextCursor: nil)))
		#expect(await client.calls.filter { $0 == .profile }.isEmpty)
	}

	@Test func postFailureCanRetryWithoutFetchingProfile() async {
		let profile = Post.preview.author
		let client = ProfileClientStub(
			profile: profile,
			pages: [
				.failure(URLError(.notConnectedToInternet)), .success(.init(posts: [.preview], nextCursor: nil))
			]
		)
		let model = ProfileViewModel(client: client, profileID: Post.preview.author.id)
		await model.load()
		#expect(model.postsState == .error(message: "Your posts couldn’t be loaded."))
		await model.retry()
		#expect(model.postsState == .loaded(.init(posts: [.preview], nextCursor: nil)))
		#expect(await client.calls == [.posts(profile.id, nil, 20), .posts(profile.id, nil, 20)])
	}

	@Test func paginationUsesSameProfileAndCanRetryFailure() async {
		let original = Post.preview
		let next = Post(
			id: UUID(),
			author: original.author,
			text: "Another post",
			imageURL: nil,
			createdAt: original.createdAt,
			isLiked: false,
			likeCount: 0
		)
		let profile = next.author
		let client = ProfileClientStub(
			profile: profile,
			pages: [
				.success(.init(posts: [.preview], nextCursor: "next")),
				.failure(URLError(.notConnectedToInternet)),
				.success(.init(posts: [.preview, next, next], nextCursor: nil))
			]
		)
		let model = ProfileViewModel(client: client, profileID: Post.preview.author.id)
		await model.load()
		await model.loadNextPage()
		#expect(model.postsState == .loaded(.init(posts: [.preview], nextCursor: "next", paginationError: "More posts couldn’t be loaded.")))
		await model.loadMoreIfNeeded(after: .preview)
		#expect(await client.calls.count == 2)
		await model.loadNextPage()
		await model.loadNextPage()
		#expect(model.postsState == .loaded(.init(posts: [.preview, next], nextCursor: nil)))
		#expect(await client.calls == [.posts(profile.id, nil, 20), .posts(profile.id, "next", 20), .posts(profile.id, "next", 20)])
	}

	@Test func invalidCursorRefreshesFirstPage() async {
		let profile = Post.preview.author
		let client = ProfileClientStub(
			profile: profile,
			pages: [
				.success(.init(posts: [.preview], nextCursor: "expired")),
				.failure(APIError(code: "invalid_cursor", message: "Expired", requestID: UUID())),
				.success(.init(posts: [], nextCursor: nil))
			]
		)
		let model = ProfileViewModel(client: client, profileID: Post.preview.author.id)
		await model.load()
		await model.loadNextPage()
		#expect(model.postsState == .loaded(.init(posts: [], nextCursor: nil)))
		#expect(await client.calls.last == .posts(profile.id, nil, 20))
	}

	@Test func failedRefreshKeepsPosts() async {
		let profile = Post.preview.author
		let client = ProfileClientStub(
			profile: profile,
			pages: [
				.success(.init(posts: [.preview], nextCursor: "next")), .failure(URLError(.notConnectedToInternet))
			]
		)
		let model = ProfileViewModel(client: client, profileID: Post.preview.author.id)
		await model.load()
		await model.refresh()
		#expect(model.postsState == .loaded(.init(posts: [.preview], nextCursor: "next")))
	}

	@Test func emptyProfileCanRefreshIntoPosts() async {
		let client = ProfileClientStub(
			profile: Post.preview.author,
			pages: [
				.success(.init(posts: [], nextCursor: nil)), .success(.init(posts: [.preview], nextCursor: nil))
			]
		)
		let model = ProfileViewModel(client: client, profileID: Post.preview.author.id)
		await model.load()
		#expect(model.postsState == .loaded(.init(posts: [], nextCursor: nil)))
		await model.refresh()
		#expect(model.postsState == .loaded(.init(posts: [.preview], nextCursor: nil)))
	}

	@Test func alreadyCancelledLoadSendsNothing() async {
		let client = ProfileClientStub(profile: Post.preview.author, pages: [])
		let model = ProfileViewModel(client: client, profileID: Post.preview.author.id)
		let load = Task {
			withUnsafeCurrentTask { $0?.cancel() }
			await model.load()
		}
		await load.value
		#expect(await client.calls.isEmpty)
	}

	@Test(.timeLimit(.minutes(1)))
	func paginationPreservesLikeUpdatesAndRejectsOverlappingRequests() async {
		let profile = Post.preview.author
		let client = ProfileClientStub(profile: profile, pages: [.success(.init(posts: [.preview], nextCursor: "next"))])
		let model = ProfileViewModel(client: client, profileID: Post.preview.author.id)
		await model.load()
		await client.setPages(nil)
		let pagination = Task { await model.loadNextPage() }
		await client.waitForPage()
		await model.loadNextPage()
		await model.refresh()
		#expect(await client.calls.count == 2)
		await model.toggleLike(postID: Post.preview.id)
		await client.completePage(.success(.init(posts: [.preview], nextCursor: nil)))
		await pagination.value
		guard case .loaded(let content) = model.postsState else {
			Issue.record("Expected loaded posts")
			return
		}
		#expect(content.posts.first?.isLiked == false)
		#expect(content.posts.first?.likeCount == 11)
	}
}

private actor ProfileClientStub: ChirpyServicing {
	enum Call: Equatable, Sendable {
		case profile
		case posts(UUID?, String?, Int)
	}
	private(set) var calls: [Call] = []
	private let profile: Profile
	private var pages: [Result<SocialFeedPage, Error>]?
	private var pendingPage: CheckedContinuation<SocialFeedPage, Error>?
	private var waiter: CheckedContinuation<Void, Never>?

	init(profile: Profile, pages: [Result<SocialFeedPage, Error>]? = nil) {
		self.profile = profile
		self.pages = pages
	}

	func setPages(_ results: [Result<SocialFeedPage, Error>]?) { pages = results }

	func fetchCurrentProfile() async throws -> Profile {
		calls.append(.profile)
		return profile
	}

	func fetchPage(profileID: UUID?, cursor: String?, limit: Int) async throws -> SocialFeedPage {
		calls.append(.posts(profileID, cursor, limit))
		if var pages {
			guard !pages.isEmpty else { throw URLError(.badServerResponse) }
			let result = pages.removeFirst()
			self.pages = pages
			return try result.get()
		}
		return try await withCheckedThrowingContinuation {
			pendingPage = $0
			waiter?.resume()
			waiter = nil
		}
	}

	func waitForPage() async {
		guard pendingPage == nil else { return }
		await withCheckedContinuation { waiter = $0 }
	}

	func completePage(_ result: Result<SocialFeedPage, Error>) {
		pendingPage?.resume(with: result)
		pendingPage = nil
	}

	func setLike(postID: UUID, isLiked: Bool) async throws -> PostLikeUpdate {
		PostLikeUpdate(postID: postID, isLiked: isLiked, likeCount: 11)
	}
	func searchPosts(query: String, cursor: String?, limit: Int) async throws -> SocialFeedPage { throw URLError(.unsupportedURL) }
	func createPost(text: String) async throws -> Post { throw URLError(.unsupportedURL) }
}
