//
//  CurrentProfileStoreTests.swift
//  ChirpyTests
//
//  Created by Samuel Yanez on 10/9/26.
//

import Foundation
import Testing

@testable import Chirpy

@MainActor
struct CurrentProfileStoreTests {
	@Test func loadsOnceAndExposesTheSharedProfile() async {
		let client = CurrentProfileClientStub(results: [.success(Post.preview.author)])
		let store = CurrentProfileStore(client: client)
		#expect(store.profile == nil)
		await store.loadIfNeeded()
		await store.loadIfNeeded()
		#expect(store.state == .loaded(Post.preview.author))
		#expect(store.profile == Post.preview.author)
		#expect(await client.calls == 1)
	}

	@Test func initialFailureCanRetry() async {
		let client = CurrentProfileClientStub(results: [
			.failure(URLError(.notConnectedToInternet)), .success(Post.preview.author)
		])
		let store = CurrentProfileStore(client: client)
		await store.loadIfNeeded()
		#expect(store.state == .error(message: "Your profile couldn’t be loaded."))
		#expect(store.profile == nil)
		await store.loadIfNeeded()
		#expect(await client.calls == 1)
		await store.retry()
		#expect(store.profile == Post.preview.author)
		#expect(await client.calls == 2)
	}

	@Test func refreshPublishesChangesAndFailureKeepsLastProfile() async {
		let original = Post.preview.author
		let changed = Profile(id: original.id, username: "changed", displayName: "Changed", avatarURL: nil)
		let client = CurrentProfileClientStub(results: [
			.success(original), .success(changed), .failure(URLError(.notConnectedToInternet))
		])
		let store = CurrentProfileStore(client: client)
		await store.loadIfNeeded()
		await store.refresh()
		#expect(store.profile == changed)
		await store.refresh()
		#expect(store.state == .loaded(changed))
		#expect(!store.isRefreshing)
	}

	@Test(.timeLimit(.minutes(1)))
	func overlappingInitialLoadsSendOneRequest() async {
		let client = CurrentProfileClientStub()
		let store = CurrentProfileStore(client: client)
		let load = Task { await store.loadIfNeeded() }
		await client.waitForRequest()
		#expect(store.state == .loading)
		await store.loadIfNeeded()
		await store.retry()
		await store.refresh()
		#expect(await client.calls == 1)
		await client.complete(.success(Post.preview.author))
		await load.value
		#expect(store.profile == Post.preview.author)
	}

	@Test(.timeLimit(.minutes(1)))
	func overlappingRefreshesKeepTheProfileVisibleAndSendOneRequest() async {
		let client = CurrentProfileClientStub(results: [.success(Post.preview.author)])
		let store = CurrentProfileStore(client: client)
		await store.loadIfNeeded()
		await client.setResults(nil)
		let refresh = Task { await store.refresh() }
		await client.waitForRequest()
		#expect(store.profile == Post.preview.author)
		#expect(store.isRefreshing)
		await store.refresh()
		#expect(await client.calls == 2)
		await client.complete(.failure(URLError(.notConnectedToInternet)))
		await refresh.value
		#expect(store.profile == Post.preview.author)
		#expect(!store.isRefreshing)
	}

	@Test(.timeLimit(.minutes(1)))
	func cancelledInitialLoadReturnsToIdleAndCanResume() async {
		let client = CurrentProfileClientStub()
		let store = CurrentProfileStore(client: client)
		let load = Task { await store.loadIfNeeded() }
		await client.waitForRequest()
		load.cancel()
		await client.complete(.success(Post.preview.author))
		await load.value
		#expect(store.state == .idle)
		await client.setResults([.success(Post.preview.author)])
		await store.loadIfNeeded()
		#expect(store.profile == Post.preview.author)
	}

	@Test(.timeLimit(.minutes(1)))
	func cancelledRefreshRetainsTheLastProfile() async {
		let original = Post.preview.author
		let changed = Profile(id: original.id, username: "changed", displayName: "Changed", avatarURL: nil)
		let client = CurrentProfileClientStub(results: [.success(original)])
		let store = CurrentProfileStore(client: client)
		await store.loadIfNeeded()
		await client.setResults(nil)
		let refresh = Task { await store.refresh() }
		await client.waitForRequest()
		refresh.cancel()
		await client.complete(.success(changed))
		await refresh.value
		#expect(store.profile == original)
		#expect(!store.isRefreshing)
	}

	@Test func alreadyCancelledLoadSendsNothing() async {
		let client = CurrentProfileClientStub()
		let store = CurrentProfileStore(client: client)
		let load = Task {
			withUnsafeCurrentTask { $0?.cancel() }
			await store.loadIfNeeded()
		}
		await load.value
		#expect(store.state == .idle)
		#expect(await client.calls == 0)
	}
}

private actor CurrentProfileClientStub: ChirpyServicing {
	private(set) var calls = 0
	private var results: [Result<Profile, Error>]?
	private var pending: CheckedContinuation<Profile, Error>?
	private var waiter: CheckedContinuation<Void, Never>?

	init(results: [Result<Profile, Error>]? = nil) { self.results = results }
	func setResults(_ results: [Result<Profile, Error>]?) { self.results = results }

	func fetchCurrentProfile() async throws -> Profile {
		calls += 1
		if var results {
			guard !results.isEmpty else { throw URLError(.badServerResponse) }
			let result = results.removeFirst()
			self.results = results
			return try result.get()
		}
		return try await withCheckedThrowingContinuation {
			pending = $0
			waiter?.resume()
			waiter = nil
		}
	}

	func waitForRequest() async {
		guard pending == nil else { return }
		await withCheckedContinuation { waiter = $0 }
	}
	func complete(_ result: Result<Profile, Error>) {
		pending?.resume(with: result)
		pending = nil
	}
	func fetchPage(profileID: UUID?, cursor: String?, limit: Int) async throws -> SocialFeedPage { throw URLError(.unsupportedURL) }
	func searchPosts(query: String, cursor: String?, limit: Int) async throws -> SocialFeedPage { throw URLError(.unsupportedURL) }
	func createPost(text: String) async throws -> Post { throw URLError(.unsupportedURL) }
	func setLike(postID: UUID, isLiked: Bool) async throws -> PostLikeUpdate { throw URLError(.unsupportedURL) }
}
