//
//  StaleFeedBar.swift
//  Chirpy
//
//  Created by Samuel Yanez on 9/2/26.
//

import SwiftUI

/// A bar that reports that the feed could not be updated, and offers to retry.
///
/// The bar leads with the age of the posts rather than with the failure. The
/// feed below it is still usable, so the age is the part the reader can act on.
///
/// The headline carries Chirpy's voice while the age line stays literal. This
/// bar can appear several times in a session, and the age is the part a reader
/// re-reads, so only the line they skim after the first time is played for
/// laughs.
struct StaleFeedBar: View {

	let updatedAt: Date

	let reason: FeedViewModel.StaleReason

	/// Whether a retry is already running, which shows progress and disables
	/// the retry control.
	let isRetrying: Bool

	let retry: () -> Void

	var body: some View {
		HStack(spacing: 12) {
			icon
				.font(.subheadline)
				.foregroundStyle(.secondary)
				.frame(width: 20)
				.accessibilityHidden(true)

			VStack(alignment: .leading, spacing: 1) {
				Text(title)
					.font(.subheadline.weight(.medium))

				Text(
					"Updated \(updatedAt, format: .relative(presentation: .named))"
				)
				.font(.caption)
				.foregroundStyle(.secondary)
			}
			// Read as one phrase, using the literal wording. A pun read aloud on
			// every appearance is noise rather than character.
			.accessibilityElement(children: .ignore)
			.accessibilityLabel(accessibilityLabel)

			Spacer(minLength: 0)

			Button("Retry", action: retry)
				.font(.subheadline.weight(.medium))
				.buttonStyle(.borderless)
				.disabled(isRetrying)
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 10)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(.bar)
		.overlay(alignment: .bottom) {
			Divider()
		}
		.accessibilityElement(children: .contain)
	}

	@ViewBuilder
	private var icon: some View {
		if isRetrying {
			ProgressView()
				.controlSize(.small)
		} else {
			Image(systemName: iconName)
		}
	}

	/// Being offline is the one cause a reader can act on, so that case keeps
	/// a literal symbol. A generic failure has nothing actionable to depict,
	/// which leaves room for the bird.
	private var iconName: String {
		switch reason {
		case .offline:
			"wifi.slash"
		case .failed:
			"bird"
		}
	}

	private var title: String {
		if isRetrying {
			return "Listening for chirps…"
		}

		return switch reason {
		case .offline: 
            "Off the wire"
		case .failed: 
            "The flock’s quiet"
		}
	}

	private var accessibilityLabel: String {
		let age = updatedAt.formatted(.relative(presentation: .named))
		return "\(literalTitle). Updated \(age)."
	}

	private var literalTitle: String {
		if isRetrying {
			return "Updating"
		}
		return switch reason {
		case .offline: "You’re offline"
		case .failed: "Couldn’t refresh"
		}
	}
}

#Preview("Offline") {
	StaleFeedBar(
		updatedAt: .now.addingTimeInterval(-7_200),
		reason: .offline,
		isRetrying: false,
		retry: {}
	)
}

#Preview("Failed") {
	StaleFeedBar(
		updatedAt: .now.addingTimeInterval(-300),
		reason: .failed,
		isRetrying: false,
		retry: {}
	)
}

#Preview("Retrying") {
	StaleFeedBar(
		updatedAt: .now.addingTimeInterval(-7_200),
		reason: .offline,
		isRetrying: true,
		retry: {}
	)
}
