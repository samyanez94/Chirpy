//
//  FeedSnapshotStoring.swift
//  Chirpy
//
//  Created by Codex on 9/1/26.
//

/// Stores a disposable first-page snapshot of the social feed.
nonisolated protocol FeedSnapshotStoring: Sendable {
	/// Returns the stored snapshot, or `nil` when there is no usable one.
	func loadSnapshot() async -> FeedSnapshot?

	/// Replaces the stored snapshot.
	func save(snapshot: FeedSnapshot) async

	/// Deletes the stored snapshot, if there is one.
	///
	/// Call this when the stored posts should no longer be shown at all, such
	/// as on sign-out.
	func removeSnapshot() async
}
