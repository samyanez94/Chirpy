//
//  PostListContent.swift
//  Chirpy
//
//  Created by Samuel Yanez on 10/8/26.
//

import Foundation

/// Loaded posts and pagination state shared by the feed and search.
nonisolated struct PostListContent: Equatable, Sendable {
	var posts: [Post]
	var nextCursor: String?
	var isLoadingNextPage = false
	var paginationError: String?

	/// Appends unique posts and advances pagination using the server's cursor.
	mutating func append(_ page: SocialFeedPage) {
		var existingIDs = Set(posts.map(\.id))
		posts.append(contentsOf: page.posts.filter { existingIDs.insert($0.id).inserted })
		nextCursor = page.nextCursor
		isLoadingNextPage = false
		paginationError = nil
	}

	/// Applies the server's authoritative like state to a post already in the list.
	mutating func apply(_ update: PostLikeUpdate) {
		guard let index = posts.firstIndex(where: { $0.id == update.postID }) else {
			return
		}
		posts[index].isLiked = update.isLiked
		posts[index].likeCount = update.likeCount
	}

	/// Returns whether a loaded post is among the last five posts.
	func isNearEnd(postID: UUID) -> Bool {
		guard let index = posts.firstIndex(where: { $0.id == postID }) else {
			return false
		}
		return index >= posts.count - min(5, posts.count)
	}
}

extension PostListContent {
	init(page: SocialFeedPage) {
		self.init(posts: [], nextCursor: nil)
		append(page)
	}
}
