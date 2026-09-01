//
//  AuthorHeaderView.swift
//  Chirpy
//
//  Created by Samuel Yanez on 9/1/26.
//

import SwiftUI

struct AuthorHeaderView: View {
    let author: Author
    let createdAt: Date

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(author.displayName)
                    .bold()

                Text("@\(author.username)")
                    .foregroundStyle(.secondary)

                Spacer(minLength: 4)

                Text(createdAt, style: .relative)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(author.displayName)
                    .bold()

                Text("@\(author.username)")
                    .foregroundStyle(.secondary)

                Text(createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}
