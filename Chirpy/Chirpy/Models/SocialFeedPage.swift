//
//  SocialFeedPage.swift
//  Chirpy
//
//  Created by Samuel Yanez on 8/31/26.
//

import Foundation

/// A page of posts returned by the social-feed API.
nonisolated struct SocialFeedPage: Decodable, Equatable, Sendable {
    /// The posts included in this page.
    let posts: [Post]

    /// An opaque cursor used to request the next page.
    let nextCursor: String?
}
