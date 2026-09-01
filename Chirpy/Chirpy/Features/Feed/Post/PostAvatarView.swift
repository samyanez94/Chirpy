//
//  PostAvatarView.swift
//  Chirpy
//
//  Created by Samuel Yanez on 9/1/26.
//

import SwiftUI

struct PostAvatarView: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .foregroundStyle(.secondary)
        }
        .frame(width: 44, height: 44)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }
}
