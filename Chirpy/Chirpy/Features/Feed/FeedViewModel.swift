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
		case loaded(content: FeedContent)
		case error(message: String)
	}

	struct FeedContent: Equatable {
		var posts: [Post]
		var nextCursor: String?
		var paginationState: PaginationState = .idle
	}

	enum PaginationState: Equatable {
		case idle
		case loading
		case error(message: String)
	}

	private static let pageSize = 20

	private let client: any SocialFeedServicing

	private(set) var state: State = .idle

	@ObservationIgnored
	private var pendingLikePostIDs = Set<UUID>()

	init(client: any SocialFeedServicing) {
		self.client = client
	}

	/// Loads the first page of posts when the feed is idle.
	///
	/// This method updates ``state`` to reflect loading, success, cancellation,
	/// or failure. Calls made after the feed leaves the idle state are ignored.
	func load() async {
		guard state == .idle else { return }

		state = .loading

		do {
			let page = try await client.fetchPage(
				cursor: nil,
				limit: Self.pageSize
			)
			state = .loaded(content: page.feedContent)
		} catch is CancellationError {
			state = .idle
		} catch {
			state = .error(
				message: "The feed couldn’t be loaded."
			)
		}
	}

	/// Replaces the loaded feed with a freshly fetched first page.
	///
	/// The current content remains unchanged if the refresh fails or if the feed
	/// is not currently loaded.
	func refresh() async {
		guard case .loaded = state else {
			return
		}

		do {
			let page = try await client.fetchPage(
				cursor: nil,
				limit: Self.pageSize
			)
			state = .loaded(content: page.feedContent)
		} catch {
			return
		}
	}

	/// Fetches and appends the next available page of posts.
	///
	/// The request is ignored when there is no next cursor or another pagination
	/// request is already in progress. Posts already present in the feed are not
	/// appended again.
	func loadNextPage() async {
		guard case .loaded(let content) = state,
			let cursor = content.nextCursor,
			content.paginationState != .loading
		else {
			return
		}

		updateContent {
			$0.paginationState = .loading
		}

		do {
			let page = try await client.fetchPage(
				cursor: cursor,
				limit: Self.pageSize
			)

			updateContent(expectedCursor: cursor) { content in
				let existingIDs = Set(content.posts.map(\.id))

				content.posts.append(
					contentsOf: page.posts.filter {
						!existingIDs.contains($0.id)
					}
				)

				content.nextCursor = page.nextCursor
				content.paginationState = .idle
			}
		} catch is CancellationError {
			updateContent(expectedCursor: cursor) {
				$0.paginationState = .idle
			}
		} catch {
			updateContent(expectedCursor: cursor) {
				$0.paginationState = .error(
					message: "More posts couldn’t be loaded."
				)
			}
		}
	}

	/// Loads the next page when the given post is near the end of the feed.
	///
	/// - Parameter post: The post whose appearance may trigger pagination.
	func loadMoreIfNeeded(after post: Post) async {
		guard case .loaded(let content) = state,
			let index = content.posts.firstIndex(where: {
				$0.id == post.id
			})
		else {
			return
		}

		let thresholdIndex = content.posts.index(
			content.posts.endIndex,
			offsetBy: -min(5, content.posts.count)
		)

		guard index >= thresholdIndex else {
			return
		}

		await loadNextPage()
	}

	/// Toggles the current user's like state for a loaded post.
	///
	/// The server response supplies the authoritative like state and count.
	/// Repeated requests for the same post are ignored while an update is in
	/// progress, and failures leave the post unchanged.
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

			updateContent { content in
				guard
					let index = content.posts.firstIndex(where: {
						$0.id == update.postID
					})
				else {
					return
				}
				content.posts[index].isLiked = update.isLiked
				content.posts[index].likeCount = update.likeCount
			}
		} catch {
			return
		}
	}

	private func updateContent(
		expectedCursor: String? = nil,
		_ update: (inout FeedContent) -> Void
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
}

extension SocialFeedPage {
	fileprivate var feedContent: FeedViewModel.FeedContent {
		.init(
			posts: posts,
			nextCursor: nextCursor
		)
	}
}
