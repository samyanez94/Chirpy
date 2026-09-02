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
		var isLoadingNextPage = false
		var freshness: Freshness = .current
	}

	/// How current the displayed posts are believed to be.
	///
	/// This describes presentation only. Whether a request is in flight is
	/// tracked separately by ``isFetchingFirstPage``.
	enum Freshness: Equatable {
		/// The posts are current as far as the app knows.
		case current

		/// The most recent attempt to update the posts failed.
		///
		/// - Parameters:
		///   - updatedAt: When the displayed posts were last fetched.
		///   - reason: Why the update did not succeed.
		case stale(updatedAt: Date, reason: StaleReason)
	}

	/// Why the posts on screen could not be updated.
	enum StaleReason: Equatable {
		/// The device has no usable network connection.
		case offline

		/// The request reached the network but did not succeed.
		case failed
	}

	private static let pageSize = 20

	private let client: any SocialFeedServicing

	private let snapshotStore: any FeedSnapshotStoring

	private(set) var state: State = .idle

	@ObservationIgnored
	private var pendingLikePostIDs = Set<UUID>()

	/// Whether a first-page request is in flight, from ``load()`` or
	/// ``refresh()``.
	private(set) var isFetchingFirstPage = false

	/// When the displayed posts were last fetched from the server.
	///
	/// Seeded from a snapshot's save date when the feed starts from cache.
	@ObservationIgnored
	private var lastSuccessfulFetchAt: Date?

	init(
		client: any SocialFeedServicing,
		snapshotStore: any FeedSnapshotStoring = StubFeedSnapshotStore()
	) {
		self.client = client
		self.snapshotStore = snapshotStore
	}

	/// Loads the first page of posts when the feed is idle.
	///
	/// This method updates ``state`` to reflect loading, success, cancellation,
	/// or failure. Calls made after the feed leaves the idle state are ignored.
	func load() async {
		guard state == .idle else { return }

		state = .loading
		isFetchingFirstPage = true
		defer {
			isFetchingFirstPage = false
		}

		var isShowingCachedPosts = false

		if let snapshot = await snapshotStore.loadSnapshot(),
			case .loading = state
		{
			isShowingCachedPosts = true
			lastSuccessfulFetchAt = snapshot.savedAt
			state = .loaded(content: snapshot.page.feedContent)
		}

		do {
			try await fetchFirstPage()
		} catch is CancellationError {
			if isShowingCachedPosts == false {
				state = .idle
			}
		} catch {
			if isShowingCachedPosts {
				markStale(after: error)
			} else {
				state = .error(
					message: "The feed couldn’t be loaded."
				)
			}
		}
	}

	/// Replaces the loaded feed with a freshly fetched first page.
	///
	/// The posts on screen are kept if the refresh fails, but are marked
	/// ``Freshness/stale(updatedAt:reason:)`` so the feed can say so. A cancelled
	/// refresh leaves the feed untouched, as does one started while the feed is
	/// not loaded or another first-page request is in flight.
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
			markStale(after: error)
		}
	}

	/// Retries loading the first page after the feed enters an error state.
	///
	/// Calls made from any state other than ``State/error(message:)`` are
	/// ignored.
	func retry() async {
		guard case .error = state else {
			return
		}
		state = .idle
		await load()
	}

	/// Fetches and appends the next available page of posts.
	///
	/// The request is ignored when there is no next cursor or another pagination
	/// request is already in progress. Posts already present in the feed are not
	/// appended again.
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
				content.isLoadingNextPage = false
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

	/// Fetches the first page, publishes it, and records it as the newest
	/// posts the app has seen.
	private func fetchFirstPage() async throws {
		let page = try await client.fetchPage(
			cursor: nil,
			limit: Self.pageSize
		)
		lastSuccessfulFetchAt = .now
		state = .loaded(content: page.feedContent)
		await snapshotStore.save(snapshot: FeedSnapshot(page: page))
	}

	/// Marks the loaded posts as stale after a failed update.
	private func markStale(after error: any Error) {
		guard let lastSuccessfulFetchAt else {
			return
		}
		updateContent {
			$0.freshness = .stale(
				updatedAt: lastSuccessfulFetchAt,
				reason: Self.staleReason(for: error)
			)
		}
	}

	/// Classifies a failed update as a connectivity problem or anything else.
	///
	/// Only errors that clearly mean the device cannot reach the network count
	/// as ``StaleReason/offline``. Ambiguous ones, such as a timeout or an
	/// unreachable host, are reported as ``StaleReason/failed`` rather than
	/// blaming the user's connection for what may be a server problem.
	private static func staleReason(for error: any Error) -> StaleReason {
		guard let error = error as? URLError else {
			return .failed
		}

		switch error.code {
		case .notConnectedToInternet,
			.networkConnectionLost,
			.dataNotAllowed,
			.internationalRoamingOff:
			return .offline
		default:
			return .failed
		}
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
