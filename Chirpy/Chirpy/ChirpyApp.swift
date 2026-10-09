//
//  ChirpyApp.swift
//  Chirpy
//
//  Created by Samuel Yanez on 8/31/26.
//

import SwiftUI

@main
struct ChirpyApp: App {

	private let client = ChirpyClient(
		baseURL: AppConfiguration.baseURL,
		httpClient: AuthenticatedHTTPClient(apiKey: AppConfiguration.apiKey)
	)

	var body: some Scene {
		WindowGroup {
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
		}
	}
}
