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
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        ProgressView()
                    }
                    .accessibilityLabel("Loading post image")

            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .accessibilityLabel(
                        "Image attached to \(authorDisplayName)’s post"
                    )

            case .failure:
                Label("Image unavailable", systemImage: "photo")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            @unknown default:
                EmptyView()
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 12))
    }
}
