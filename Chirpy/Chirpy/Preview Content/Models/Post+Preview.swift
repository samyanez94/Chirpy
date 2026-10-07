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
			Updated my profile portrait. The expression says ‘financially secure.’ The finances are bottle caps.

			Please direct all peanut offers to the branch office. Management is twelve crows and we remember every face.

			No, the pebble collection is not for sale.
			""",
		imageURL: avatarURL(species: "crow"),
		createdAt: preview.createdAt,
		isLiked: false,
		likeCount: 24
	)

	static let preview = Post(
		id: UUID(uuidString: "10000000-0000-4000-8000-000000000002")!,
		author: Author(
			id: UUID(uuidString: "00000000-0000-4000-8000-000000000002")!,
			username: "shinycollector",
			displayName: "Corvid Crow",
			avatarURL: avatarURL(species: "crow")
		),
		text: "Found a bottle cap. Won’t be taking questions about my net worth.",
		imageURL: nil,
		createdAt: .now.addingTimeInterval(-900),
		isLiked: true,
		likeCount: 12
	)

	static let flockPreview: [Post] = [
		.preview,
		birdPreview(number: 1, species: "sparrow", name: "Pip Sparrow", username: "crumbclub",
			text: "Found a crumb so big I had to invite the group chat. Nobody tell the pigeon."),
		birdPreview(number: 3, species: "pigeon", name: "Petal Pigeon", username: "platform3",
			text: "The human dropped half a bagel. Incredible day for the local economy."),
		birdPreview(number: 4, species: "owl", name: "Olive Owl", username: "afterdark",
			text: "Who scheduled this meeting for daylight."),
		birdPreview(number: 5, species: "goose", name: "Gus Goose", username: "rightofway",
			text: "Reminder: the path belongs to me. This is also the reminder.")
	]

	private static func avatarURL(species: String) -> URL {
		AppConfiguration.baseURL.appending(path: "storage/v1/object/public/chirpy-avatars/\(species)-v1.jpg")
	}

	private static func birdPreview(number: Int, species: String, name: String, username: String, text: String) -> Post {
		let suffix = String(format: "%012d", number)
		return Post(
			id: UUID(uuidString: "10000000-0000-4000-8000-\(suffix)")!,
			author: Author(
				id: UUID(uuidString: "00000000-0000-4000-8000-\(suffix)")!,
				username: username,
				displayName: name,
				avatarURL: avatarURL(species: species)
			),
			text: text,
			imageURL: nil,
			createdAt: .now.addingTimeInterval(-Double(number) * 1800),
			isLiked: false,
			likeCount: number * 3
		)
	}
}
