import SwiftUI

struct PostDetailView: View {
	let post: Post
	let onLike: () -> Void

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
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(16)
		}
		.navigationTitle("Post")
		.navigationBarTitleDisplayMode(.inline)
	}
}

#Preview("Text Post") {
	NavigationStack {
		PostDetailView(post: .preview, onLike: {})
	}
}

#Preview("Image Post · Dark") {
	NavigationStack {
		PostDetailView(post: .detailPreview, onLike: {})
	}
	.preferredColorScheme(.dark)
}

#Preview("Long Post · Large Text") {
	NavigationStack {
		PostDetailView(post: .detailPreview, onLike: {})
	}
	.environment(\.dynamicTypeSize, .accessibility3)
}
