//
//  PostToolbarView.swift
//  Chirpy
//
//  Created by Samuel Yanez on 9/1/26.
//

import SwiftUI

struct PostToolbarView: View {
	let isLiked: Bool
	let likeCount: Int
	let onLike: () -> Void

	var body: some View {
		HStack {
			Button(action: onLike) {
				HStack(spacing: 4) {
					Image(systemName: isLiked ? "heart.fill" : "heart")
						.symbolEffect(.bounce, value: isLiked)
					Text(likeCount, format: .number)
						.contentTransition(
							.numericText(value: Double(likeCount))
						)
				}
				.animation(.snappy, value: isLiked)
				.animation(.snappy, value: likeCount)
			}
			.font(.subheadline)
			.buttonStyle(.plain)
			.foregroundStyle(isLiked ? .red : .secondary)
			.contentShape(.rect)
			.accessibilityLabel(isLiked ? "Unlike post" : "Like post")
			.accessibilityValue("\(likeCount) likes")
			Spacer()
		}
	}
}
