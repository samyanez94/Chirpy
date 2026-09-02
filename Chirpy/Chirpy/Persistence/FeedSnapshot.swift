//
//  FeedSnapshot.swift
//  Chirpy
//
//  Created by Codex on 9/1/26.
//

import Foundation

/// A versioned, disposable copy of the first social-feed page.
nonisolated struct FeedSnapshot: Codable, Equatable, Sendable {
	static let currentVersion = 1

	let version: Int
	let savedAt: Date
	let page: SocialFeedPage

	init(
		page: SocialFeedPage,
		savedAt: Date = .now,
		version: Int = Self.currentVersion
	) {
		self.version = version
		self.savedAt = savedAt
		self.page = page
	}
}
