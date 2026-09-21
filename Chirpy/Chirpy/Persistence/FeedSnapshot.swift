//
//  FeedSnapshot.swift
//  Chirpy
//
//  Created by Codex on 9/1/26.
//

import Foundation

/// A disposable copy of the first social-feed page.
nonisolated struct FeedSnapshot: Codable, Equatable, Sendable {
	/// When the posts were fetched from the server.
	let savedAt: Date

	/// The requested page size, which may exceed the number of returned posts.
	let limit: Int

	let page: SocialFeedPage

	init(page: SocialFeedPage, limit: Int, savedAt: Date = .now) {
		self.savedAt = savedAt
		self.page = page
		self.limit = limit
	}
}
