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
        try result.get()
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
