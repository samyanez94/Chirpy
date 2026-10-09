//
//  ProfileViewModel.swift
//  Chirpy
//
//  Created by Samuel Yanez on 10/9/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class ProfileViewModel {
	enum PostsState: Equatable {
		case idle
		case loading
		case loaded(PostListContent)
		case error(message: String)
	}

	private(set) var postsState: PostsState = .idle

	private static let pageSize = 20

	private let client: any ChirpyServicing

	private let profileID: UUID

	@ObservationIgnored private var isFetchingFirstPage = false

	@ObservationIgnored private var pendingLikePostIDs = Set<UUID>()

	@ObservationIgnored private var removedPostIDs = Set<UUID>()

	init(client: any ChirpyServicing, profileID: UUID) {
		self.client = client
		self.profileID = profileID
	}

	/// Loads posts for the identity supplied by the shared current-profile store.
	func load() async {
		guard postsState == .idle,
			!isFetchingFirstPage,
			!Task.isCancelled
		else {
			return
		}
		isFetchingFirstPage = true
		defer {
			isFetchingFirstPage = false
		}
		postsState = .loading
		do {
			let page = try await client.fetchPage(
				profileID: profileID,
				cursor: nil,
				limit: Self.pageSize
			)
			try Task.checkCancellation()
			postsState = .loaded(PostListContent(page: page, excluding: removedPostIDs))
		} catch {
			postsState = isCancellation(error) ? .idle : .error(message: "Your posts couldn’t be loaded.")
		}
	}

	func retry() async {
		guard !isFetchingFirstPage else {
			return
		}
		if case .error = postsState {
			postsState = .idle
		}
		await load()
	}

	/// Refreshes posts, keeping existing content on failure.
	func refresh() async {
		guard !isFetchingFirstPage,
			!Task.isCancelled,
			pendingLikePostIDs.isEmpty
		else {
			return
		}
		if case .loaded(let content) = postsState,
			content.isLoadingNextPage
		{
			return
		}
		isFetchingFirstPage = true
		defer {
			isFetchingFirstPage = false
		}
		do {
			let page = try await client.fetchPage(profileID: profileID, cursor: nil, limit: Self.pageSize)
			try Task.checkCancellation()
			postsState = .loaded(PostListContent(page: page, excluding: removedPostIDs))
		} catch {
			// A failed or cancelled refresh leaves the current posts intact.
		}
	}

	func loadNextPage() async {
		guard case .loaded(let content) = postsState,
			let cursor = content.nextCursor,
			!content.isLoadingNextPage,
			!isFetchingFirstPage,
			!Task.isCancelled
		else {
			return
		}

		updateContent {
			$0.isLoadingNextPage = true
			$0.paginationError = nil
		}
		do {
			let page = try await client.fetchPage(profileID: profileID, cursor: cursor, limit: Self.pageSize)
			try Task.checkCancellation()
			updateContent(expectedCursor: cursor) { $0.append(page) }
		} catch {
			updateContent(expectedCursor: cursor) {
				$0.isLoadingNextPage = false
				if !isCancellation(error) {
					$0.paginationError = "More posts couldn’t be loaded."
				}
			}
			if let error = error as? APIError,
				error.code == "invalid_cursor",
				!Task.isCancelled
			{
				await refresh()
			}
		}
	}

	func loadMoreIfNeeded(after post: Post) async {
		guard case .loaded(let content) = postsState,
			content.paginationError == nil,
			content.isNearEnd(postID: post.id)
		else {
			return
		}
		await loadNextPage()
	}

	func toggleLike(postID: UUID) async {
		guard !isFetchingFirstPage,
			case .loaded(let content) = postsState,
			let post = content.posts.first(where: { $0.id == postID }),
			pendingLikePostIDs.insert(postID).inserted
		else {
			return
		}
		defer {
			pendingLikePostIDs.remove(postID)
		}
		do {
			let update = try await client.setLike(postID: postID, isLiked: !post.isLiked)
			try Task.checkCancellation()
			updateContent { $0.apply(update) }
		} catch {
			// Keep the server-confirmed like state when an update fails.
		}
	}

	/// Removes a deleted post locally and excludes it from older in-flight responses.
	func removePost(postID: UUID) {
		removedPostIDs.insert(postID)
		updateContent { $0.remove(postID: postID) }
	}

	private func updateContent(expectedCursor: String? = nil, _ update: (inout PostListContent) -> Void) {
		guard case .loaded(var content) = postsState else {
			return
		}
		if let expectedCursor,
			content.nextCursor != expectedCursor
		{
			return
		}
		update(&content)
		content.posts.removeAll { removedPostIDs.contains($0.id) }
		postsState = .loaded(content)
	}

	private func isCancellation(_ error: Error) -> Bool {
		error is CancellationError || Task.isCancelled
	}
}
