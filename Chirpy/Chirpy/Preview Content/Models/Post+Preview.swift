//
//  Post+Preview.swift
//  Chirpy
//
//  Created by Samuel Yanez on 9/1/26.
//

import Foundation

extension Post {
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
