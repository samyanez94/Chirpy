//
//  Author.swift
//  Chirpy
//
//  Created by Samuel Yanez on 8/31/26.
//

import Foundation

/// A profile that publishes posts in the social feed.
nonisolated struct Author: Identifiable, Codable, Equatable, Sendable {
	/// The author's unique identifier.
	let id: UUID

	/// The unique username used to identify the author.
	let username: String

	/// The author's user-facing name.
	let displayName: String

	/// The remote location of the author's avatar image, when present.
	let avatarURL: URL?
}
