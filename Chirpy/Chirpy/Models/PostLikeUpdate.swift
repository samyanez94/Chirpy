//
//  PostLikeUpdate.swift
//  Chirpy
//
//  Created by Samuel Yanez on 9/1/26.
//

import Foundation

nonisolated struct PostLikeUpdate: Decodable, Equatable, Sendable {
	let postID: UUID
	let isLiked: Bool
	let likeCount: Int
}
