//
//  CurrentProfileStore.swift
//  Chirpy
//
//  Created by Samuel Yanez on 10/9/26.
//

import Foundation
import Observation

/// The server-selected identity shared by all tabs for the lifetime of the root view.
@MainActor
@Observable
final class CurrentProfileStore {

	enum State: Equatable {
		case idle
		case loading
		case loaded(Profile)
		case error(message: String)
	}

	private(set) var state: State = .idle

	private(set) var isRefreshing = false

	var profile: Profile? {
		guard case .loaded(let profile) = state else {
			return nil
		}
		return profile
	}

	private let client: any ChirpyServicing

	init(client: any ChirpyServicing) {
		self.client = client
	}

	/// Loads once; duplicate calls and already cancelled tasks send no request.
	func loadIfNeeded() async {
		guard state == .idle,
			!Task.isCancelled
		else {
			return
		}
		state = .loading
		do {
			let profile = try await client.fetchCurrentProfile()
			try Task.checkCancellation()
			state = .loaded(profile)
		} catch {
			state =
				error is CancellationError || Task.isCancelled
				? .idle : .error(message: "Your profile couldn’t be loaded.")
		}
	}

	func retry() async {
		guard case .error = state,
			!Task.isCancelled
		else {
			return
		}
		state = .idle
		await loadIfNeeded()
	}

	/// Keeps the last loaded identity visible if a refresh fails or is cancelled.
	func refresh() async {
		guard profile != nil,
			!isRefreshing,
			!Task.isCancelled
		else {
			return
		}
		isRefreshing = true
		defer {
			isRefreshing = false
		}
		do {
			let profile = try await client.fetchCurrentProfile()
			try Task.checkCancellation()
			state = .loaded(profile)
		} catch {
			// Browsing and ownership checks continue using the last loaded profile.
		}
	}
}
