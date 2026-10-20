//
//  Profile.swift
//  Chirpy
//
//  Created by Samuel Yanez on 8/31/26.
//

import Foundation

/// A public profile used for the current identity and post authors.
nonisolated struct Profile: Identifiable, Codable, Equatable, Sendable {
	/// The profile's unique identifier.
	let id: UUID

	/// The unique username used to identify the profile.
	let username: String

	/// The profile's user-facing name.
	let displayName: String

	/// The remote location of the profile's avatar image, when present.
	let avatarURL: URL?
}
