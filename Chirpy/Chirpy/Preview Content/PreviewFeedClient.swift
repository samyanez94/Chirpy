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

	func setLike(
		postID: UUID,
		isLiked: Bool
	) async throws -> PostLikeUpdate {
		let page = try result.get()
		guard let post = page.posts.first(where: { $0.id == postID }) else {
			throw PreviewError.requestFailed
		}

		var likeCount = post.likeCount
		if isLiked != post.isLiked {
			likeCount += isLiked ? 1 : -1
		}

		return PostLikeUpdate(
			postID: postID,
			isLiked: isLiked,
			likeCount: max(0, likeCount)
		)
	}
}

enum PreviewError: Error {
	case requestFailed
}

extension SocialFeedPage {
	static let preview = SocialFeedPage(
		posts: [.preview],
		nextCursor: nil
	)
}
