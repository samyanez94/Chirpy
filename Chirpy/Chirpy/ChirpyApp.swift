//
//  ChirpyApp.swift
//  Chirpy
//
//  Created by Samuel Yanez on 8/31/26.
//

import SwiftUI

@main
struct ChirpyApp: App {
	var body: some Scene {
		WindowGroup {
			TabView {
				Tab("Home", systemImage: "house") {
					NavigationStack {
						FeedView(
							client: FeedClient(
								baseURL: AppConfiguration.baseURL,
								httpClient: AuthenticatedHTTPClient(apiKey: AppConfiguration.apiKey)
							)
						)
					}
				}
				Tab("Search", systemImage: "magnifyingglass", role: .search) {
					NavigationStack {
						SearchView()
					}
				}
			}
		}
	}
}
