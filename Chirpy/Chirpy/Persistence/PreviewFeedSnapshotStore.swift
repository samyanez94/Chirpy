//
//  PreviewFeedSnapshotStore.swift
//  Chirpy
//
//  Created by Samuel Yanez on 9/2/26.
//

import Foundation

/// A snapshot store that always returns a fixed snapshot, for previews.
nonisolated struct PreviewFeedSnapshotStore: FeedSnapshotStoring {
	let snapshot: FeedSnapshot?

	func loadSnapshot() async -> FeedSnapshot? {
		snapshot
	}

	func save(snapshot: FeedSnapshot) async {}

	func removeSnapshot() async {}
}
