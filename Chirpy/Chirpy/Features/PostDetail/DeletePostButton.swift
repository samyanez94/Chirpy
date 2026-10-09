//
//  DeletePostButton.swift
//  Chirpy
//
//  Created by Samuel Yanez on 10/9/26.
//

import SwiftUI

struct DeletePostButton: View {

	let model: PostDeletionModel

	let onDeleted: () -> Void

	@State private var isConfirming = false

	@State private var isShowingError = false

	var body: some View {
		Group {
			if model.isDeleting {
				ProgressView()
					.accessibilityLabel("Deleting post")
			} else {
				Menu("Post actions", systemImage: "ellipsis") {
					Button("Delete post", systemImage: "trash", role: .destructive) {
						isConfirming = true
					}
				}
			}
		}
		.disabled(model.isDeleting)
		.confirmationDialog(
			"Delete this post?",
			isPresented: $isConfirming,
			titleVisibility: .visible
		) {
			Button("Delete post", role: .destructive) { delete() }
			Button("Cancel", role: .cancel) {}
		} message: {
			Text("This can’t be undone.")
		}
		.alert(
			"Couldn’t delete post",
			isPresented: $isShowingError
		) {
			Button("Try Again") { delete() }
			Button("Cancel", role: .cancel) {}
		} message: {
			Text(model.errorMessage ?? "Please try again.")
		}
	}

	private func delete() {
		Task {
			if await model.delete() {
				onDeleted()
			} else {
				isShowingError = model.errorMessage != nil
			}
		}
	}
}
