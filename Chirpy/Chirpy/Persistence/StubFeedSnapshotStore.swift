//
//  StubFeedSnapshotStore.swift
//  Chirpy
//
//  Created by Samuel Yanez on 9/2/26.
//

/// A snapshot store that returns a fixed snapshot and persists nothing.
///
/// Used for previews, for tests, and as the default for callers that do not
/// want persistence.
nonisolated struct StubFeedSnapshotStore: FeedSnapshotStoring {
	let snapshot: FeedSnapshot?

	init(snapshot: FeedSnapshot? = nil) {
		self.snapshot = snapshot
	}

	func loadSnapshot() async -> FeedSnapshot? {
		snapshot
	}

	func save(snapshot: FeedSnapshot) async {}

	func removeSnapshot() async {}
}
