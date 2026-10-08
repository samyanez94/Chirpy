//
//  PreviewChirpyClient.swift
//  Chirpy
//
//  Created by Samuel Yanez on 9/1/26.
//

import Foundation

struct PreviewChirpyClient: ChirpyServicing {
	let result: Result<SocialFeedPage, PreviewError>
	var profile: Author? = nil

	func fetchCurrentProfile() async throws -> Author {
		_ = try result.get()
		if let profile {
			return profile
		}
		return await Post.preview.author
	}

	func fetchPage(
		profileID: UUID?,
		cursor: String?,
		limit: Int
	) async throws -> SocialFeedPage {
		let page = try result.get()
		guard let profileID else { return page }
		return SocialFeedPage(
			posts: page.posts.filter { $0.author.id == profileID },
			nextCursor: page.nextCursor
		)
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
