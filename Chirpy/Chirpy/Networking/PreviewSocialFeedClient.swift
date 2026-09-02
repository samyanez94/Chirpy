//
//  PreviewSocialFeedClient.swift
//  Chirpy
//
//  Created by Samuel Yanez on 9/1/26.
//

import Foundation

struct PreviewSocialFeedClient: SocialFeedServicing {
	let result: Result<SocialFeedPage, PreviewError>

	func fetchPage(
		cursor: String?,
		limit: Int
	) async throws -> SocialFeedPage {
		switch result {
		case .success(let page):
			return page
		case .failure(let error):
			throw error
		}
	}

	func setLike(
		postID: UUID,
		isLiked: Bool
	) async throws -> PostLikeUpdate {
		PostLikeUpdate(
			postID: UUID(),
			isLiked: false,
			likeCount: 0
		)
	}
}

enum PreviewError: Error {
	case requestFailed
}

extension SocialFeedPage {
	static let preview = SocialFeedPage(
		posts: [.preview],
		nextCursor: "next-page"
	)
}
