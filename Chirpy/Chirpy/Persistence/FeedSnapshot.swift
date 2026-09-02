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

	let page: SocialFeedPage

	init(page: SocialFeedPage, savedAt: Date = .now) {
		self.savedAt = savedAt
		self.page = page
	}
}
