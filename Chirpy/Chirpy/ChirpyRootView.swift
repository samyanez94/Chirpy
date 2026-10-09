//
//  ChirpyRootView.swift
//  Chirpy
//
//  Created by Samuel Yanez on 10/9/26.
//

import SwiftUI

struct ChirpyRootView: View {

	private let client: any ChirpyServicing

	@State private var currentProfile: CurrentProfileStore

	init(client: any ChirpyServicing) {
		self.client = client
		_currentProfile = State(initialValue: CurrentProfileStore(client: client))
	}

	var body: some View {
		TabView {
			Tab("Home", systemImage: "house") {
				NavigationStack {
					FeedView(client: client)
				}
			}
			Tab("Search", systemImage: "magnifyingglass") {
				NavigationStack {
					SearchView(client: client)
				}
			}
			Tab("Profile", systemImage: "person.crop.circle") {
				NavigationStack {
					ProfileView(client: client)
				}
			}
		}
		.environment(currentProfile)
		.task {
			await currentProfile.loadIfNeeded()
		}
	}
}
