//
//  FeedView.swift
//  Chirpy
//
//  Created by Samuel Yanez on 9/1/26.
//

import Foundation
import SwiftUI

struct FeedView: View {

	private let client: any FeedServicing

	@State private var viewModel: FeedViewModel

	@State private var isComposing = false

	init(client: any FeedServicing) {
		self.client = client
		_viewModel = State(initialValue: FeedViewModel(client: client))
	}

	var body: some View {
		Group {
			switch viewModel.state {
			case .idle, .loading:
				ProgressView()
			case .loaded(let page):
				List {
					ForEach(page.posts) { post in
						PostRow(post: post) {
							Task {
								await viewModel.toggleLike(postID: post.id)
							}
						}
						.task {
							await viewModel.loadMoreIfNeeded(after: post)
						}
					}
				}
				.listStyle(.plain)
				.refreshable {
					await viewModel.refresh()
				}
			case .error(let message):
				ContentUnavailableView {
					Label("Something went wrong", systemImage: "wifi.exclamationmark")
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
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Button("New post", systemImage: "square.and.pencil") {
					isComposing = true
				}
			}
		}
		.sheet(isPresented: $isComposing) {
			PostComposerView { text in
				_ = try await client.createPost(text: text)
				// Replacing the model reloads the entire feed and discards older in-flight results.
				viewModel = FeedViewModel(client: client)
			}
		}
		.navigationTitle("Home")
		.toolbarBackground(.visible, for: .navigationBar)
		.navigationBarTitleDisplayMode(.inline)
		.navigationDestination(for: UUID.self) { postID in
			if case .loaded(let content) = viewModel.state,
				let post = content.posts.first(where: { $0.id == postID })
			{
				PostDetailView(post: post) {
					Task {
						await viewModel.toggleLike(postID: postID)
					}
				}
			} else {
				ContentUnavailableView(
					"Post unavailable",
					systemImage: "text.bubble",
					description: Text("This post is no longer in your feed.")
				)
				.navigationTitle("Post")
				.navigationBarTitleDisplayMode(.inline)
			}
		}
		.task(id: ObjectIdentifier(viewModel)) {
			guard case .idle = viewModel.state else {
				return
			}
			await viewModel.load()
		}
	}
}

#Preview("Loaded") {
	NavigationStack {
		FeedView(
			client: PreviewFeedClient(result: .success(.preview))
		)
	}
}

#Preview("Error") {
	NavigationStack {
		FeedView(
			client: PreviewFeedClient(result: .failure(.requestFailed))
		)
	}
}
