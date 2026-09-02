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
			throw error.thrown
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
	case offline

	/// The error the client actually throws.
	///
	/// Offline previews need a real `URLError` so the feed classifies them the
	/// same way it would at runtime.
	var thrown: any Error {
		switch self {
		case .requestFailed:
			self
		case .offline:
			URLError(.notConnectedToInternet)
		}
	}
}

extension SocialFeedPage {
	static let preview = SocialFeedPage(
		posts: [.preview],
		nextCursor: "next-page"
	)
}
