//
//  FeedView.swift
//  Chirpy
//
//  Created by Samuel Yanez on 9/1/26.
//

import Foundation
import SwiftUI

struct FeedView: View {

	@State private var viewModel: FeedViewModel

	init(viewModel: FeedViewModel) {
		_viewModel = State(initialValue: viewModel)
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
				.safeAreaInset(edge: .top, spacing: 0) {
					if case .stale(let updatedAt, let reason) = page.freshness {
						StaleFeedBar(
							updatedAt: updatedAt,
							reason: reason,
							isRetrying: viewModel.isFetchingFirstPage
						) {
							Task {
								await viewModel.refresh()
							}
						}
						.transition(.move(edge: .top).combined(with: .opacity))
					}
				}
				.animation(.snappy, value: page.freshness)
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
		.navigationTitle("Home")
		.toolbarBackground(.visible, for: .navigationBar)
		.navigationBarTitleDisplayMode(.inline)
		.task {
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
			viewModel: FeedViewModel(
				client: PreviewSocialFeedClient(result: .success(.preview))
			)
		)
	}
}

#Preview("Error") {
	NavigationStack {
		FeedView(
			viewModel: FeedViewModel(
				client: PreviewSocialFeedClient(result: .failure(.requestFailed))
			)
		)
	}
}

#Preview("Stale — offline") {
	NavigationStack {
		FeedView(
			viewModel: FeedViewModel(
				client: PreviewSocialFeedClient(result: .failure(.offline)),
				snapshotStore: StubFeedSnapshotStore(
					snapshot: FeedSnapshot(
						page: .preview,
						savedAt: .now.addingTimeInterval(-7_200)
					)
				)
			)
		)
	}
}

#Preview("Stale — request failed") {
	NavigationStack {
		FeedView(
			viewModel: FeedViewModel(
				client: PreviewSocialFeedClient(result: .failure(.requestFailed)),
				snapshotStore: StubFeedSnapshotStore(
					snapshot: FeedSnapshot(
						page: .preview,
						savedAt: .now.addingTimeInterval(-300)
					)
				)
			)
		)
	}
}
