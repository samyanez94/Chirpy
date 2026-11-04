//
//  ProfileView.swift
//  Chirpy
//
//  Created by Samuel Yanez on 10/9/26.
//

import SwiftUI

struct ProfileView: View {
	private let client: any ChirpyServicing

	@Environment(CurrentProfileStore.self) private var currentProfile

	init(client: any ChirpyServicing) {
		self.client = client
	}

	var body: some View {
		Group {
			switch currentProfile.state {
			case .idle, .loading:
				ProgressView("Loading profile…")
			case .loaded(let profile):
				ProfileContentView(profile: profile, client: client)
					.id(profile.id)
			case .error(let message):
				ContentUnavailableView {
					Label("Profile unavailable", systemImage: "wifi.exclamationmark")
				} description: {
					Text(message)
				} actions: {
					Button("Try Again") {
						Task { await currentProfile.retry() }
					}
				}
			}
		}
		.navigationTitle("Profile")
		.navigationBarTitleDisplayMode(.inline)
		.toolbarBackground(.visible, for: .navigationBar)
	}
}

#Preview("Loaded") {
	@Previewable @State var currentProfile = CurrentProfileStore(
		client: PreviewChirpyClient(result: .success(.preview))
	)
	let client = PreviewChirpyClient(result: .success(.preview))
	NavigationStack {
		ProfileView(client: client)
	}
	.environment(currentProfile)
	.task { await currentProfile.loadIfNeeded() }
}

#Preview("Empty") {
	@Previewable @State var currentProfile = CurrentProfileStore(
		client: PreviewChirpyClient(result: .success(.init(posts: [], nextCursor: nil)))
	)
	let client = PreviewChirpyClient(result: .success(.init(posts: [], nextCursor: nil)))
	NavigationStack {
		ProfileView(client: client)
	}
	.environment(currentProfile)
	.task { await currentProfile.loadIfNeeded() }
}

#Preview("Error") {
	@Previewable @State var currentProfile = CurrentProfileStore(
		client: PreviewChirpyClient(result: .failure(.requestFailed))
	)
	let client = PreviewChirpyClient(result: .failure(.requestFailed))
	NavigationStack {
		ProfileView(client: client)
	}
	.environment(currentProfile)
	.task { await currentProfile.loadIfNeeded() }
}

#Preview("Dark · Large Text") {
	@Previewable @State var currentProfile = CurrentProfileStore(
		client: PreviewChirpyClient(result: .success(.preview))
	)
	let client = PreviewChirpyClient(result: .success(.preview))
	NavigationStack {
		ProfileView(client: client)
	}
	.environment(currentProfile)
	.task { await currentProfile.loadIfNeeded() }
	.preferredColorScheme(.dark)
	.environment(\.dynamicTypeSize, .accessibility3)
}
