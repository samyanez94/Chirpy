import SwiftUI

struct PostComposerView: View {
	let onPost: (String) async throws -> Void

	@Environment(\.dismiss) private var dismiss
	@FocusState private var isFocused: Bool
	@State private var text = ""
	@State private var isPosting = false
	@State private var errorMessage: String?
	@State private var showsError = false

	private var trimmedText: String {
		// Match JavaScript String.trim() on the backend.
		let whitespace = CharacterSet.whitespacesAndNewlines
			.union(CharacterSet(charactersIn: "\u{FEFF}"))
			.subtracting(CharacterSet(charactersIn: "\u{0085}"))
		return text.trimmingCharacters(in: whitespace)
	}

	private var characterCount: Int { trimmedText.unicodeScalars.count }

	var body: some View {
		NavigationStack {
			VStack(alignment: .leading, spacing: 12) {
				TextField("What’s on your mind?", text: $text, axis: .vertical)
					.font(.body)
					.lineLimit(1...12)
					.focused($isFocused)
					.disabled(isPosting)
					.accessibilityLabel("Post text")

				Spacer(minLength: 0)

				Text("\(characterCount)/300")
					.font(.footnote)
					.monospacedDigit()
					.foregroundStyle(characterCount > 300 ? .red : .secondary)
					.frame(maxWidth: .infinity, alignment: .trailing)
					.accessibilityLabel("\(characterCount) of 300 characters")
			}
			.padding(16)
			.navigationTitle("New Post")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") { dismiss() }
						.disabled(isPosting)
				}
				ToolbarItem(placement: .confirmationAction) {
					if isPosting {
						ProgressView().accessibilityLabel("Posting")
					} else {
						Button("Post", action: submit)
							.bold()
							.disabled(characterCount == 0 || characterCount > 300)
					}
				}
			}
			.interactiveDismissDisabled(isPosting)
			.alert("Couldn’t post", isPresented: $showsError) {
				Button("OK", role: .cancel) {}
			} message: {
				Text(errorMessage ?? "Please try again.")
			}
			.task { isFocused = true }
		}
		.presentationDetents([.large])
	}

	private func submit() {
		guard !isPosting, (1...300).contains(characterCount) else { return }
		let draft = trimmedText
		isPosting = true
		Task {
			defer { isPosting = false }
			do {
				try await onPost(draft)
				dismiss()
			} catch let error as APIError {
				errorMessage = error.message
				showsError = true
			} catch {
				errorMessage = "Your draft is still here. Check your connection and try again."
				showsError = true
			}
		}
	}
}

#Preview {
	PostComposerView { _ in }
}
