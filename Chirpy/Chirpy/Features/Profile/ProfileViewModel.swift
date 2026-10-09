import Foundation
import Observation

@MainActor
@Observable
final class ProfileViewModel {
	enum State: Equatable {
		case idle
		case loading
		case loaded(Author)
		case error(message: String)
	}

	enum PostsState: Equatable {
		case idle
		case loading
		case loaded(PostListContent)
		case error(message: String)
	}

	private(set) var state: State = .idle

	private(set) var postsState: PostsState = .idle

	private static let pageSize = 20

	private let client: any ChirpyServicing

	@ObservationIgnored private var isFetchingFirstPage = false

	@ObservationIgnored private var pendingLikePostIDs = Set<UUID>()

	init(client: any ChirpyServicing) {
		self.client = client
	}

	/// Publishes the profile before loading its posts, retaining the header on a post failure.
	func load() async {
		guard !isFetchingFirstPage,
              !Task.isCancelled else {
            return
        }
		if case .loaded = state {
			guard postsState == .idle else {
                return
            }
		} else {
			guard state == .idle else {
                return
            }
		}
		isFetchingFirstPage = true
		defer {
            isFetchingFirstPage = false
        }

		if state == .idle {
			state = .loading
			do {
				let profile = try await client.fetchCurrentProfile()
				try Task.checkCancellation()
				state = .loaded(profile)
			} catch {
				state = isCancellation(error) ? .idle : .error(message: "Your profile couldn’t be loaded.")
				return
			}
		}

		guard case .loaded(let profile) = state else {
            return
        }
		postsState = .loading
		do {
			let page = try await client.fetchPage(profileID: profile.id, cursor: nil, limit: Self.pageSize)
			try Task.checkCancellation()
			postsState = .loaded(PostListContent(page: page))
		} catch {
			postsState = isCancellation(error) ? .idle : .error(message: "Your posts couldn’t be loaded.")
		}
	}

	func retry() async {
		guard !isFetchingFirstPage else {
            return
        }
		if case .error = state {
            state = .idle
        }
		if case .error = postsState {
            postsState = .idle
        }
		await load()
	}

	/// Refreshes the header and first page together, keeping existing content on failure.
	func refresh() async {
		guard case .loaded = state,
			!isFetchingFirstPage,
			pendingLikePostIDs.isEmpty else {
            return
        }
		if case .loaded(let content) = postsState,
            content.isLoadingNextPage {
            return
        }
		isFetchingFirstPage = true
		defer {
            isFetchingFirstPage = false
        }
		do {
			let profile = try await client.fetchCurrentProfile()
			try Task.checkCancellation()
			let page = try await client.fetchPage(profileID: profile.id, cursor: nil, limit: Self.pageSize)
			try Task.checkCancellation()
			state = .loaded(profile)
			postsState = .loaded(PostListContent(page: page))
		} catch {
			// A failed or cancelled refresh leaves the current header and posts intact.
		}
	}

	func loadNextPage() async {
		guard case .loaded(let profile) = state,
			case .loaded(let content) = postsState,
			let cursor = content.nextCursor,
			!content.isLoadingNextPage,
			!isFetchingFirstPage,
			!Task.isCancelled else {
            return
        }

		updateContent {
			$0.isLoadingNextPage = true
			$0.paginationError = nil
		}
		do {
			let page = try await client.fetchPage(profileID: profile.id, cursor: cursor, limit: Self.pageSize)
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
                !Task.isCancelled {
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
			pendingLikePostIDs.insert(postID).inserted else {
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

	private func updateContent(expectedCursor: String? = nil, _ update: (inout PostListContent) -> Void) {
		guard case .loaded(var content) = postsState else {
            return
        }
		if let expectedCursor,
           content.nextCursor != expectedCursor {
            return
        }
		update(&content)
		postsState = .loaded(content)
	}

	private func isCancellation(_ error: Error) -> Bool {
		error is CancellationError || Task.isCancelled
	}
}
