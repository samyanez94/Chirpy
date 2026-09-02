//
//  DisabledFeedSnapshotStore.swift
//  Chirpy
//
//  Created by Codex on 9/1/26.
//

/// A snapshot store for previews, tests, and callers that do not want persistence.
nonisolated struct DisabledFeedSnapshotStore: FeedSnapshotStoring {
	func loadSnapshot() async -> FeedSnapshot? {
		nil
	}

	func save(snapshot: FeedSnapshot) async {}

	func removeSnapshot() async {}
}
