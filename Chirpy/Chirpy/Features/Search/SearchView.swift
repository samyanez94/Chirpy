//
//  SearchView.swift
//  Chirpy
//
//  Created by Samuel Yanez on 10/8/26.
//

import SwiftUI

struct SearchView: View {
	private let client: any ChirpyServicing

	@State private var searchText = ""

	@State private var viewModel: SearchViewModel

	init(client: any ChirpyServicing) {
		self.client = client
		_viewModel = State(initialValue: SearchViewModel(query: "", client: client))
	}

	var body: some View {
		Group {
			switch viewModel.state {
			case .idle:
				ContentUnavailableView(
					"Search Chirpy",
					systemImage: "magnifyingglass",
					description: Text("Find posts from the flock.")
				)
			case .loading:
				ProgressView("Searching…")
			case .loaded(let content):
				if content.posts.isEmpty {
					ContentUnavailableView.search(text: viewModel.query)
				} else {
					results(content)
				}
			case .error(let message):
				ContentUnavailableView {
					Label("Search unavailable", systemImage: "wifi.exclamationmark")
				} description: {
					Text(message)
				} actions: {
					Button("Try Again") {
						Task {
							await viewModel.retry()
						}
					}
				}
			}
		}
		.navigationTitle("Search")
		.navigationBarTitleDisplayMode(.inline)
		.toolbarBackground(.visible, for: .navigationBar)
		.searchable(text: $searchText, prompt: "Search posts")
		.autocorrectionDisabled()
		.textInputAutocapitalization(.never)
		.task(id: searchText) {
			await search()
		}
		.navigationDestination(for: UUID.self) { postID in
			if case .loaded(let content) = viewModel.state,
				let post = content.posts.first(where: { $0.id == postID })
			{
				PostDetailView(post: post) {
					Task { await viewModel.toggleLike(postID: postID) }
				}
			} else {
				ContentUnavailableView(
					"Post unavailable",
					systemImage: "text.bubble",
					description: Text("This post is no longer in your search results.")
				)
				.navigationTitle("Post")
				.navigationBarTitleDisplayMode(.inline)
			}
		}
	}

	private func search() async {
		guard !Task.isCancelled else {
			return
		}
		let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
		if viewModel.query != query || viewModel.state == .loading {
			viewModel = SearchViewModel(query: query, client: client)
		}
		guard viewModel.state == .idle,
			!query.isEmpty
		else {
			return
		}
		let model = viewModel
		do {
			try await Task.sleep(for: .milliseconds(300))
			await model.load()
		} catch {
			// SwiftUI cancels the debounce when the query changes or the view disappears.
		}
	}

	private func results(_ content: PostListContent) -> some View {
		List {
			ForEach(content.posts) { post in
				PostRow(post: post) {
					Task {
						await viewModel.toggleLike(postID: post.id)
					}
				}
				.task {
					await viewModel.loadMoreIfNeeded(after: post)
				}
			}
			if let message = content.paginationError {
				VStack(spacing: 8) {
					Text(message)
					Button("Try Again") {
						Task {
							await viewModel.loadNextPage()
						}
					}
				}
				.frame(maxWidth: .infinity)
			} else if content.isLoadingNextPage {
				ProgressView("Loading more results…")
					.frame(maxWidth: .infinity)
			}
		}
		.listStyle(.plain)
		.scrollDismissesKeyboard(.interactively)
	}
}

#Preview {
	NavigationStack {
		SearchView(client: PreviewChirpyClient(result: .success(.preview)))
	}
}

#Preview("Dark · Large Text") {
	NavigationStack {
		SearchView(client: PreviewChirpyClient(result: .success(.preview)))
	}
	.preferredColorScheme(.dark)
	.environment(\.dynamicTypeSize, .accessibility3)
}
