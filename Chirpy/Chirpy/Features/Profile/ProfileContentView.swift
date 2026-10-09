//
//  ProfileContentView.swift
//  Chirpy
//
//  Created by Samuel Yanez on 10/9/26.
//

import Foundation
import SwiftUI

struct ProfileContentView: View {

	let profile: Profile

	@Environment(CurrentProfileStore.self) private var currentProfile

	@State private var viewModel: ProfileViewModel

	init(profile: Profile, client: any ChirpyServicing) {
		self.profile = profile
		_viewModel = State(
			initialValue: ProfileViewModel(
				client: client,
				profileID: profile.id
			)
		)
	}

	var body: some View {
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
			await currentProfile.refresh()
			guard currentProfile.profile?.id == profile.id else {
				return
			}
			await viewModel.refresh()
		}
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
