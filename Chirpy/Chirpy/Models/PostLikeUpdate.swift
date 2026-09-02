//
//  PostLikeUpdate.swift
//  Chirpy
//
//  Created by Samuel Yanez on 9/1/26.
//

import Foundation

/// The server-authoritative like state returned after updating a post.
nonisolated struct PostLikeUpdate: Decodable, Equatable, Sendable {
	/// The unique identifier of the updated post.
	let postID: UUID

	/// A Boolean value that indicates whether the current user likes the post.
	let isLiked: Bool

	/// The total number of likes the post has received.
	let likeCount: Int
}
