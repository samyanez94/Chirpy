//
//  PostDeletionModelTests.swift
//  ChirpyTests
//
//  Created by Samuel Yanez on 10/9/26.
//

import Foundation
import Testing

@testable import Chirpy

@MainActor
struct PostDeletionModelTests {
	@Test func successDeletesTheRequestedPostOnlyOnce() async {
		let id = UUID()
		let client = DeletionClientStub(results: [.success(())])
		let model = PostDeletionModel(postID: id, client: client)
		#expect(await model.delete())
		#expect(!(await model.delete()))
		#expect(await client.postIDs == [id])
		#expect(!model.isDeleting)
		#expect(model.errorMessage == nil)
	}

	@Test func failureLeavesThePostAndCanRetry() async {
		let client = DeletionClientStub(results: [.failure(URLError(.notConnectedToInternet)), .success(())])
		let model = PostDeletionModel(postID: UUID(), client: client)
		#expect(!(await model.delete()))
		#expect(model.errorMessage != nil)
		#expect(!model.isDeleting)
		#expect(await model.delete())
		#expect(model.errorMessage == nil)
		#expect(await client.postIDs.count == 2)
	}

	@Test(arguments: ["post_not_found", "unauthorized", "internal_error"])
	func onlyPostNotFoundIsTreatedAsAlreadyGone(code: String) async {
		let client = DeletionClientStub(results: [.failure(APIError(code: code, message: "Failed", requestID: UUID()))])
		let model = PostDeletionModel(postID: UUID(), client: client)
		#expect(await model.delete() == (code == "post_not_found"))
		#expect((model.errorMessage == nil) == (code == "post_not_found"))
	}

	@Test(.timeLimit(.minutes(1)))
	func duplicateRequestsAreIgnoredWhileDeleting() async {
		let client = DeletionClientStub()
		let model = PostDeletionModel(postID: UUID(), client: client)
		let deletion = Task { await model.delete() }
		await client.waitForRequest()
		#expect(model.isDeleting)
		#expect(!(await model.delete()))
		#expect(await client.postIDs.count == 1)
		await client.complete(.success(()))
		#expect(await deletion.value)
		#expect(!model.isDeleting)
	}

	@Test func cancellationDoesNotShowAnErrorAndCanRetry() async {
		let client = DeletionClientStub(results: [.failure(CancellationError()), .success(())])
		let model = PostDeletionModel(postID: UUID(), client: client)
		#expect(!(await model.delete()))
		#expect(model.errorMessage == nil)
		#expect(!model.isDeleting)
		#expect(await model.delete())
	}

	@Test func alreadyCancelledTaskSendsNothing() async {
		let client = DeletionClientStub()
		let model = PostDeletionModel(postID: UUID(), client: client)
		let deletion = Task {
			withUnsafeCurrentTask { $0?.cancel() }
			return await model.delete()
		}
		#expect(!(await deletion.value))
		#expect(await client.postIDs.isEmpty)
		#expect(!model.isDeleting)
	}
}

private actor DeletionClientStub: ChirpyServicing {
	private(set) var postIDs: [UUID] = []
	private var results: [Result<Void, Error>]?
	private var pending: CheckedContinuation<Void, Error>?
	private var waiter: CheckedContinuation<Void, Never>?

	init(results: [Result<Void, Error>]? = nil) { self.results = results }
	func deletePost(postID: UUID) async throws {
		postIDs.append(postID)
		if var results {
			guard !results.isEmpty else { throw URLError(.badServerResponse) }
			let result = results.removeFirst()
			self.results = results
			return try result.get()
		}
		try await withCheckedThrowingContinuation {
			pending = $0
			waiter?.resume()
			waiter = nil
		}
	}
	func waitForRequest() async {
		guard pending == nil else { return }
		await withCheckedContinuation { waiter = $0 }
	}
	func complete(_ result: Result<Void, Error>) {
		pending?.resume(with: result)
		pending = nil
	}
	func fetchCurrentProfile() async throws -> Profile { throw URLError(.unsupportedURL) }
	func fetchPage(profileID: UUID?, cursor: String?, limit: Int) async throws -> SocialFeedPage { throw URLError(.unsupportedURL) }
	func searchPosts(query: String, cursor: String?, limit: Int) async throws -> SocialFeedPage { throw URLError(.unsupportedURL) }
	func createPost(text: String) async throws -> Post { throw URLError(.unsupportedURL) }
	func setLike(postID: UUID, isLiked: Bool) async throws -> PostLikeUpdate { throw URLError(.unsupportedURL) }
}
