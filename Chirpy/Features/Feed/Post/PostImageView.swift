//
//  PostImageView.swift
//  Chirpy
//
//  Created by Samuel Yanez on 9/1/26.
//

import SwiftUI

struct PostImageView: View {
	let url: URL
	let authorDisplayName: String

	var body: some View {
		AsyncImage(url: url) { image in
			image
				.resizable()
				.scaledToFill()
				.accessibilityLabel(
					"Image attached to \(authorDisplayName)’s post"
				)
		} placeholder: {
			Rectangle()
				.fill(.quaternary)
				.overlay {
					ProgressView()
				}
				.accessibilityLabel("Loading post image")
		}
		.aspectRatio(16 / 9, contentMode: .fit)
		.clipShape(.rect(cornerRadius: 12))
	}
}
