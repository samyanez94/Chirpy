//
//  PostDetailView.swift
//  Chirpy
//
//  Created by Samuel Yanez on 9/27/26.
//

import SwiftUI

struct PostDetailView: View {

	let post: Post

	let onLike: () -> Void

	let onDeleted: (UUID) -> Void

	@Environment(CurrentProfileStore.self) private var currentProfile

	@Environment(\.dismiss) private var dismiss

	@State private var deletion: PostDeletionModel

	init(
		post: Post,
		client: any ChirpyServicing,
		onDeleted: @escaping (UUID) -> Void,
		onLike: @escaping () -> Void
	) {
		self.post = post
		self.onLike = onLike
		self.onDeleted = onDeleted
		_deletion = State(
			initialValue: PostDeletionModel(
				postID: post.id,
				client: client
			)
		)
	}

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				HStack(alignment: .top, spacing: 12) {
					PostAvatarView(url: post.author.avatarURL)

					VStack(alignment: .leading, spacing: 4) {
						Text(post.author.displayName)
							.font(.headline)
						Text("@\(post.author.username)")
							.font(.subheadline)
							.foregroundStyle(.secondary)
					}
					.accessibilityElement(children: .combine)
				}

				Text(post.text)
					.font(.body)
					.textSelection(.enabled)

				if let imageURL = post.imageURL {
					PostImageView(
						url: imageURL,
						authorDisplayName: post.author.displayName
					)
				}

				Text(post.createdAt, format: .dateTime.month(.wide).day().year().hour().minute())
					.font(.footnote)
					.foregroundStyle(.secondary)

				Divider()

				PostToolbarView(
					isLiked: post.isLiked,
					likeCount: post.likeCount,
					onLike: onLike
				)
				.disabled(deletion.isDeleting)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(16)
		}
		.toolbar {
			if currentProfile.profile?.id == post.author.id {
				ToolbarItem(placement: .topBarTrailing) {
					DeletePostButton(model: deletion) {
						dismiss()
						onDeleted(post.id)
					}
				}
			}
		}
		.navigationTitle("Post")
		.navigationBarTitleDisplayMode(.inline)
	}
}

#Preview("Text Post") {
	@Previewable @State var currentProfile = CurrentProfileStore(
		client: PreviewChirpyClient(
			result: .success(.preview),
			profile: Post.preview.author
		)
	)
	NavigationStack {
		PostDetailView(
			post: .preview,
			client: PreviewChirpyClient(result: .success(.preview)),
			onDeleted: { _ in },
			onLike: {}
		)
	}
	.environment(currentProfile)
	.task { await currentProfile.loadIfNeeded() }
}

#Preview("Image Post · Dark") {
	@Previewable @State var currentProfile = CurrentProfileStore(
		client: PreviewChirpyClient(
			result: .success(.preview),
			profile: Post.detailPreview.author
		)
	)
	NavigationStack {
		PostDetailView(
			post: .detailPreview,
			client: PreviewChirpyClient(result: .success(.preview)),
			onDeleted: { _ in },
			onLike: {}
		)
	}
	.environment(currentProfile)
	.task { await currentProfile.loadIfNeeded() }
	.preferredColorScheme(.dark)
}

#Preview("Long Post · Large Text") {
	@Previewable @State var currentProfile = CurrentProfileStore(
		client: PreviewChirpyClient(
			result: .success(.preview),
			profile: Post.detailPreview.author
		)
	)
	NavigationStack {
		PostDetailView(
			post: .detailPreview,
			client: PreviewChirpyClient(result: .success(.preview)),
			onDeleted: { _ in },
			onLike: {}
		)
	}
	.environment(currentProfile)
	.task { await currentProfile.loadIfNeeded() }
	.environment(\.dynamicTypeSize, .accessibility3)
}
