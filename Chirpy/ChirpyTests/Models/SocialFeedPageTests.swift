//
//  SocialFeedPageTests.swift
//  ChirpyTests
//
//  Created by Samuel Yanez on 8/31/26.
//

import Foundation
import Testing
@testable import Chirpy

struct SocialFeedPageTests {
    @Test func decodesSocialFeedPage() throws {
        let fixtureURL = try #require(
            Bundle(for: TestBundleToken.self).url(
                forResource: "social-feed-page",
                withExtension: "json"
            ),
            "The social-feed-page.json fixture must be included in the ChirpyTests bundle."
        )
        let data = try Data(contentsOf: fixtureURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let page = try decoder.decode(SocialFeedPage.self, from: data)
        let post = try #require(page.posts.first)

        #expect(page.posts.count == 1)
        #expect(page.nextCursor == "opaque-next-page-cursor")
        #expect(post.id.uuidString == "10000000-0000-4000-8000-000000000001")
        #expect(post.author.id.uuidString == "00000000-0000-4000-8000-000000000002")
        #expect(post.author.username == "swiftbird")
        #expect(post.author.displayName == "Swift Bird")
        #expect(post.author.avatarURL?.absoluteString == "https://example.com/avatars/swiftbird.jpg")
        #expect(post.text == "Building Chirpy one test at a time.")
        #expect(post.imageURL?.absoluteString == "https://example.com/posts/chirpy.jpg")
        #expect(abs(post.createdAt.timeIntervalSince1970 - 1_788_205_337.123) < 0.001)
        #expect(post.isLiked)
        #expect(post.likeCount == 12)
    }
}

private final class TestBundleToken {}
