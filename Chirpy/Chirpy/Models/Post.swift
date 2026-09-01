//
//  Post.swift
//  Chirpy
//
//  Created by Samuel Yanez on 8/31/26.
//

import Foundation

/// A message published by an author in the social feed.
nonisolated struct Post: Identifiable, Codable, Equatable, Sendable {
    /// The post's unique identifier.
    let id: UUID

    /// The profile that published the post.
    let author: Author

    /// The text content of the post.
    let text: String

    /// The remote location of the post's attached image, when present.
    let imageURL: URL?

    /// The date and time when the post was published.
    let createdAt: Date

    /// A Boolean value that indicates whether the current user likes the post.
    let isLiked: Bool

    /// The total number of likes the post has received.
    let likeCount: Int
}
