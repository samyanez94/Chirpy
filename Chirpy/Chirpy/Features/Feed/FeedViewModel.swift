//
//  FeedViewModel.swift
//  Chirpy
//
//  Created by Samuel Yanez on 9/1/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class FeedViewModel {

	enum State: Equatable {
		case idle
		case loading
		case loaded(content: PostListContent)
		case error(message: String)
	}

	private static let pageSize = 20

	private let client: any ChirpyServicing

	private(set) var state: State = .idle

	@ObservationIgnored
	private var pendingLikePostIDs = Set<UUID>()

	@ObservationIgnored
	private var isFetchingFirstPage = false

	init(client: any ChirpyServicing) {
		self.client = client
	}

	/// Loads the first page of posts when the feed is idle.
	///
	/// This method updates ``state`` to reflect loading, success, cancellation, or failure. Calls made after the feed leaves the idle state are ignored.
	func load() async {
		guard state == .idle else { return }

		state = .loading
		isFetchingFirstPage = true
		defer {
			isFetchingFirstPage = false
		}

		do {
			try await fetchFirstPage()
		} catch {
			if error is CancellationError || Task.isCancelled {
				state = .idle
			} else {
				state = .error(message: "The feed couldn’t be loaded.")
			}
		}
	}

	/// Replaces the loaded feed with a freshly fetched first page.
	///
	/// The posts on screen are kept if the refresh fails. A cancelled refresh also leaves the feed untouched, as does one started while the feed is not loaded or another first-page request is in flight.
	func refresh() async {
		guard case .loaded(let content) = state,
			content.isLoadingNextPage == false,
			isFetchingFirstPage == false
		else {
			return
		}

		isFetchingFirstPage = true
		defer {
			isFetchingFirstPage = false
		}

		do {
			try await fetchFirstPage()
		} catch is CancellationError {
			return
		} catch {
			return
		}
	}

	/// Retries loading the first page after the feed enters an error state.
	///
	/// Calls made from any state other than ``State/error(message:)`` are ignored.
	func retry() async {
		guard case .error = state else {
			return
		}
		state = .idle
		await load()
	}

	/// Fetches and appends the next available page of posts.
	///
	/// The request is ignored when there is no next cursor or another pagination request is already in progress. Posts already present in the feed are not appended again.
	func loadNextPage() async {
		guard case .loaded(let content) = state,
			let cursor = content.nextCursor,
			content.isLoadingNextPage == false,
			isFetchingFirstPage == false
		else {
			return
		}

		updateContent {
			$0.isLoadingNextPage = true
		}

		do {
			let page = try await client.fetchPage(cursor: cursor, limit: Self.pageSize)

			updateContent(expectedCursor: cursor) {
				$0.append(page)
			}
		} catch let error as APIError where error.code == "invalid_cursor" {
			updateContent(expectedCursor: cursor) {
				$0.isLoadingNextPage = false
			}
			await refresh()
		} catch {
			updateContent(expectedCursor: cursor) {
				$0.isLoadingNextPage = false
			}
		}
	}

	/// Loads the next page when the given post is near the end of the feed.
	///
	/// - Parameter post: The post whose appearance may trigger pagination.
	func loadMoreIfNeeded(after post: Post) async {
		guard case .loaded(let content) = state,
			content.isNearEnd(postID: post.id)
		else {
			return
		}

		await loadNextPage()
	}

	/// Toggles the current user's like state for a loaded post.
	///
	/// The server response supplies the authoritative like state and count. Repeated requests for the same post are ignored while an update is in progress, and failures leave the post unchanged.
	///
	/// - Parameter postID: The unique identifier of the post to update.
	func toggleLike(postID: UUID) async {
		guard case .loaded(let content) = state,
			let post = content.posts.first(where: { $0.id == postID }),
			pendingLikePostIDs.insert(postID).inserted
		else {
			return
		}

		defer {
			pendingLikePostIDs.remove(postID)
		}

		do {
			let update = try await client.setLike(
				postID: postID,
				isLiked: post.isLiked == false
			)

			updateContent {
				$0.apply(update)
			}
		} catch {
			return
		}
	}

	private func updateContent(
		expectedCursor: String? = nil,
		_ update: (inout PostListContent) -> Void
	) {
		guard case .loaded(var content) = state else {
			return
		}

		if let expectedCursor,
			content.nextCursor != expectedCursor
		{
			return
		}

		update(&content)
		state = .loaded(content: content)
	}

	/// Fetches and publishes the first page.
	private func fetchFirstPage() async throws {
		let page = try await client.fetchPage(cursor: nil, limit: Self.pageSize)
		try Task.checkCancellation()
		state = .loaded(content: PostListContent(page: page))
	}
}
