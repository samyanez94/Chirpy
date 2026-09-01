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
				List(page.posts) { post in
					PostRow(post: post) {
						print("Post was liked")
					}
				}
				.listStyle(.plain)
				.refreshable {
					await viewModel.refresh()
				}
			case .error(let message):
				ContentUnavailableView(
					"Something went wrong",
					systemImage: "wifi.exclamationmark",
					description: Text(message)
				)
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
