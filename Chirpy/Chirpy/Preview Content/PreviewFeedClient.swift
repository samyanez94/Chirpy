//
//  PreviewFeedClient.swift
//  Chirpy
//
//  Created by Samuel Yanez on 9/1/26.
//

import Foundation

struct PreviewFeedClient: FeedServicing {
	let result: Result<SocialFeedPage, PreviewError>

	func fetchPage(
		cursor: String?,
		limit: Int
	) async throws -> SocialFeedPage {
		try result.get()
	}

	func searchPosts(
		query: String,
		cursor: String?,
		limit: Int
	) async throws -> SocialFeedPage {
		try result.get()
	}

	func createPost(text: String) async throws -> Post {
		await Post.preview
	}

	func setLike(
		postID: UUID,
		isLiked: Bool
	) async throws -> PostLikeUpdate {
		PostLikeUpdate(postID: postID, isLiked: isLiked, likeCount: isLiked ? 1 : 0)
	}
}

enum PreviewError: Error {
	case requestFailed
}

extension SocialFeedPage {
	static let preview = SocialFeedPage(
		posts: Post.flockPreview,
		nextCursor: nil
	)
}
