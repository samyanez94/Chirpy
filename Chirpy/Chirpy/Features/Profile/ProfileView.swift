import SwiftUI

struct ProfileView: View {
	@State private var viewModel: ProfileViewModel

	init(client: any ChirpyServicing) {
		_viewModel = State(initialValue: ProfileViewModel(client: client))
	}

	var body: some View {
		Group {
			switch viewModel.state {
			case .idle, .loading:
				ProgressView("Loading profile…")
			case .loaded(let profile):
				profileContent(profile)
			case .error(let message):
				ContentUnavailableView {
					Label("Profile unavailable", systemImage: "wifi.exclamationmark")
				} description: {
					Text(message)
				} actions: {
					retryButton
				}
			}
		}
		.navigationTitle("Profile")
		.navigationBarTitleDisplayMode(.inline)
		.toolbarBackground(.visible, for: .navigationBar)
		.task {
            await viewModel.load()
        }
		.navigationDestination(for: UUID.self) { postID in
			if case .loaded(let content) = viewModel.postsState,
				let post = content.posts.first(where: { $0.id == postID })
			{
				PostDetailView(post: post) {
					Task { await viewModel.toggleLike(postID: postID) }
				}
			} else {
				ContentUnavailableView(
					"Post unavailable",
					systemImage: "text.bubble",
					description: Text("This post is no longer in your profile.")
				)
				.navigationTitle("Post")
				.navigationBarTitleDisplayMode(.inline)
			}
		}
	}

	private func profileContent(_ profile: Author) -> some View {
		ScrollView {
			LazyVStack(alignment: .leading, spacing: 0) {
				ProfileHeaderView(profile: profile)
					.padding(.bottom, 8)
				Divider()
                    .padding(.bottom, 8)
				Text("Posts")
					.font(.headline)
					.accessibilityAddTraits(.isHeader)
					.padding(.vertical, 8)
				posts
			}
			.padding(.horizontal, 16)
			.padding(.bottom, 16)
		}
		.refreshable {
			await viewModel.refresh()
		}
	}

	@ViewBuilder
	private var posts: some View {
		switch viewModel.postsState {
		case .idle, .loading:
			ProgressView("Loading posts…")
				.frame(maxWidth: .infinity)
		case .error(let message):
			ContentUnavailableView {
				Label("Posts unavailable", systemImage: "wifi.exclamationmark")
			} description: {
				Text(message)
			} actions: {
				retryButton
			}
		case .loaded(let content):
			if content.posts.isEmpty {
				ContentUnavailableView(
					"No posts yet",
					systemImage: "text.bubble",
					description: Text("Your posts will appear here.")
				)
			} else {
				ForEach(content.posts) { post in
					PostRow(post: post) {
						Task {
                            await viewModel.toggleLike(postID: post.id)
                        }
					}
					.padding(.vertical, 8)
					.task {
						await viewModel.loadMoreIfNeeded(after: post)
					}
					if post.id != content.posts.last?.id {
						Divider()
							.padding(.leading, 56)
					}
				}
			}
			if let message = content.paginationError {
				VStack(spacing: 8) {
					Text(message)
					Button("Try Again") {
						Task { await viewModel.loadNextPage() }
					}
				}
				.frame(maxWidth: .infinity)
			} else if content.isLoadingNextPage {
				ProgressView("Loading more posts…")
					.frame(maxWidth: .infinity)
			}
		}
	}

	private var retryButton: some View {
		Button("Try Again") {
			Task {
                await viewModel.retry()
            }
		}
	}
}

#Preview("Loaded") {
	NavigationStack {
		ProfileView(client: PreviewChirpyClient(result: .success(.preview)))
	}
}

#Preview("Empty") {
	NavigationStack {
		ProfileView(client: PreviewChirpyClient(result: .success(.init(posts: [], nextCursor: nil))))
	}
}

#Preview("Error") {
	NavigationStack {
		ProfileView(client: PreviewChirpyClient(result: .failure(.requestFailed)))
	}
}

#Preview("Dark · Large Text") {
	NavigationStack {
		ProfileView(client: PreviewChirpyClient(result: .success(.preview)))
	}
	.preferredColorScheme(.dark)
	.environment(\.dynamicTypeSize, .accessibility3)
}
