//
//  ProfileHeaderView.swift
//  Chirpy
//
//  Created by Samuel Yanez on 10/9/26.
//

import SwiftUI

struct ProfileHeaderView: View {
	let profile: Profile

	var body: some View {
		HStack(alignment: .bottom, spacing: 12) {
			AsyncImage(url: profile.avatarURL) { image in
				image.resizable().scaledToFill()
			} placeholder: {
				Image(systemName: "person.crop.circle.fill")
					.resizable()
					.foregroundStyle(.secondary)
			}
			.frame(width: 88, height: 88)
			.clipShape(.circle)
			.accessibilityHidden(true)

			VStack(alignment: .leading, spacing: 4) {
				Text(profile.displayName)
					.font(.title2)
					.bold()
					.accessibilityAddTraits(.isHeader)
				Text("@\(profile.username)")
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(.vertical, 8)
	}
}

#Preview {
	ProfileHeaderView(profile: Post.preview.author)
		.padding()
}
