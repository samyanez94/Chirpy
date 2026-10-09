//
//  PostDeletionModel.swift
//  Chirpy
//
//  Created by Samuel Yanez on 10/9/26.
//

import Foundation
import Observation

/// Request state for a single detail screen's deletion control.
@MainActor
@Observable
final class PostDeletionModel {

	private let client: any ChirpyServicing

	private let postID: UUID

	private var isDeleted = false

	private(set) var isDeleting = false

	private(set) var errorMessage: String?

	init(postID: UUID, client: any ChirpyServicing) {
		self.postID = postID
		self.client = client
	}

	/// Returns true when the post is deleted or already unavailable on the server.
	func delete() async -> Bool {
		guard !isDeleting,
			!isDeleted,
			!Task.isCancelled
		else {
			return false
		}
		isDeleting = true
		errorMessage = nil
		defer {
			isDeleting = false
		}
		do {
			try await client.deletePost(postID: postID)
			isDeleted = true
			return true
		} catch let error as APIError where error.code == "post_not_found" {
			isDeleted = true
			return true
		} catch {
			if !(error is CancellationError),
				!Task.isCancelled,
				(error as? URLError)?.code != .cancelled
			{
				errorMessage = "The post couldn’t be deleted. Please try again."
			}
			return false
		}
	}
}
