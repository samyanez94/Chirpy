//
//  PostRow.swift
//  Chirpy
//
//  Created by Samuel Yanez on 9/1/26.
//

import SwiftUI

struct PostRow: View {
	let post: Post
	let onLike: () -> Void

	var body: some View {
		HStack(alignment: .top, spacing: 12) {
			PostAvatarView(url: post.author.avatarURL)

			VStack(alignment: .leading, spacing: 8) {
				AuthorHeaderView(
					author: post.author,
					createdAt: post.createdAt
				)

				Text(post.text)
					.font(.body)

				if let imageURL = post.imageURL {
					PostImageView(
						url: imageURL,
						authorDisplayName: post.author.displayName
					)
				}
				HStack {
					Button(action: onLike) {
						HStack(spacing: 4) {
							Image(systemName: post.isLiked ? "heart.fill" : "heart")
							Text(post.likeCount, format: .number)
								.contentTransition(.numericText(value: 1))
						}
					}
					.font(.subheadline)
					.buttonStyle(.plain)
					.foregroundStyle(post.isLiked ? .red : .secondary)
					.contentShape(.rect)
					.accessibilityLabel(
						post.isLiked ? "Unlike post" : "Like post"
					)
					.accessibilityValue("\(post.likeCount) likes")

					Spacer()
				}
			}
		}
		.padding(.vertical, 8)
	}
}

#Preview("Regular Post") {
	List {
		PostRow(post: .preview, onLike: {})
	}
	.listStyle(.plain)
}

#Preview("Large Text") {
	List {
		PostRow(post: .preview, onLike: {})
	}
	.listStyle(.plain)
	.environment(\.dynamicTypeSize, .accessibility3)
}
