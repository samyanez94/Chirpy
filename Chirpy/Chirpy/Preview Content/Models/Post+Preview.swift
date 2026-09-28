//
//  Post+Preview.swift
//  Chirpy
//
//  Created by Samuel Yanez on 9/1/26.
//

import Foundation

extension Post {
	static let detailPreview = Post(
		id: preview.id,
		author: preview.author,
		text: """
			Spent the morning walking along the coast, with no plans except to see where the path went.

			Sometimes slowing down is the best way to notice something new. The light on the water, the birds overhead, and a quiet place to sit made this a morning worth remembering.

			What’s your favorite place to take a break?
			""",
		imageURL: URL(string: "https://picsum.photos/id/16/800/450"),
		createdAt: preview.createdAt,
		isLiked: false,
		likeCount: 24
	)

	static let preview = Post(
		id: UUID(uuidString: "10000000-0000-4000-8000-000000000001")!,
		author: Author(
			id: UUID(uuidString: "00000000-0000-4000-8000-000000000002")!,
			username: "swiftbird",
			displayName: "Swift Bird",
			avatarURL: nil
		),
		text: "Building Chirpy one view at a time.",
		imageURL: nil,
		createdAt: .now.addingTimeInterval(-900),
		isLiked: true,
		likeCount: 12
	)
}
