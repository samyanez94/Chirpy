//
//  SearchView.swift
//  Chirpy
//
//  Created by Samuel Yanez on 10/8/26.
//

import SwiftUI

struct SearchView: View {
	@State private var searchText = ""

	var body: some View {
		ContentUnavailableView {
			Label("Search Chirpy", systemImage: "magnifyingglass")
		} description: {
			Text("Find posts from the flock. Search is coming soon.")
		}
		.navigationTitle("Search")
		.navigationBarTitleDisplayMode(.inline)
		.toolbarBackground(.visible, for: .navigationBar)
		.searchable(text: $searchText, prompt: "Search posts")
		.autocorrectionDisabled()
		.textInputAutocapitalization(.never)
	}
}

#Preview {
	NavigationStack {
		SearchView()
	}
}

#Preview("Dark · Large Text") {
	NavigationStack {
		SearchView()
	}
	.preferredColorScheme(.dark)
	.environment(\.dynamicTypeSize, .accessibility3)
}
