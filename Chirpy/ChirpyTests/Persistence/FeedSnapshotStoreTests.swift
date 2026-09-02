import Foundation
import Testing

@testable import Chirpy

struct FeedSnapshotStoreTests {

	@Test
	func returnsNilWhenNothingHasBeenSaved() async {
		let directory = makeTemporaryDirectory()
		defer { removeTemporaryDirectory(directory) }

		let store = FeedSnapshotStore(directory: directory)

		#expect(await store.loadSnapshot() == nil)
	}

	@Test
	func roundTripsASavedSnapshot() async {
		let directory = makeTemporaryDirectory()
		defer { removeTemporaryDirectory(directory) }

		let store = FeedSnapshotStore(directory: directory)
		let snapshot = FeedSnapshot(
			page: makePage(),
			savedAt: recentWholeSecond()
		)

		await store.save(snapshot: snapshot)

		#expect(await store.loadSnapshot() == snapshot)
	}

	@Test
	func discardsASnapshotOlderThanTheMaximumAge() async {
		let directory = makeTemporaryDirectory()
		defer { removeTemporaryDirectory(directory) }

		let store = FeedSnapshotStore(
			directory: directory,
			maximumAge: 60 * 60
		)

		await store.save(
			snapshot: FeedSnapshot(
				page: makePage(),
				savedAt: Date.now.addingTimeInterval(-2 * 60 * 60)
			)
		)

		#expect(await store.loadSnapshot() == nil)
		#expect(snapshotFileExists(in: directory) == false)
	}

	@Test
	func keepsASnapshotWithinTheMaximumAge() async {
		let directory = makeTemporaryDirectory()
		defer { removeTemporaryDirectory(directory) }

		let store = FeedSnapshotStore(
			directory: directory,
			maximumAge: 60 * 60
		)

		await store.save(
			snapshot: FeedSnapshot(
				page: makePage(),
				savedAt: Date.now.addingTimeInterval(-60)
			)
		)

		#expect(await store.loadSnapshot() != nil)
	}

	/// A device clock moved backwards would otherwise keep a snapshot alive
	/// past any maximum age.
	@Test
	func discardsAFutureDatedSnapshot() async {
		let directory = makeTemporaryDirectory()
		defer { removeTemporaryDirectory(directory) }

		let store = FeedSnapshotStore(directory: directory)

		await store.save(
			snapshot: FeedSnapshot(
				page: makePage(),
				savedAt: Date.now.addingTimeInterval(60 * 60)
			)
		)

		#expect(await store.loadSnapshot() == nil)
		#expect(snapshotFileExists(in: directory) == false)
	}

	@Test
	func discardsASnapshotWrittenByAnotherVersion() async {
		let directory = makeTemporaryDirectory()
		defer { removeTemporaryDirectory(directory) }

		let store = FeedSnapshotStore(directory: directory)

		await store.save(
			snapshot: FeedSnapshot(
				page: makePage(),
				savedAt: .now,
				version: FeedSnapshot.currentVersion + 1
			)
		)

		#expect(await store.loadSnapshot() == nil)
		#expect(snapshotFileExists(in: directory) == false)
	}

	/// The version gate has to fire even when the payload shape changed enough
	/// that a full decode would throw first.
	@Test
	func discardsASnapshotWhosePayloadShapeChanged() async {
		let directory = makeTemporaryDirectory()
		defer { removeTemporaryDirectory(directory) }

		write(
			#"{"version":99,"savedAt":"2026-09-01T00:00:00Z","page":{"unknown":1}}"#,
			to: directory
		)

		let store = FeedSnapshotStore(directory: directory)

		#expect(await store.loadSnapshot() == nil)
		#expect(snapshotFileExists(in: directory) == false)
	}

	@Test
	func discardsACorruptSnapshot() async {
		let directory = makeTemporaryDirectory()
		defer { removeTemporaryDirectory(directory) }

		write("not json", to: directory)

		let store = FeedSnapshotStore(directory: directory)

		#expect(await store.loadSnapshot() == nil)
		#expect(snapshotFileExists(in: directory) == false)
	}

	@Test
	func removeSnapshotDeletesAStoredSnapshot() async {
		let directory = makeTemporaryDirectory()
		defer { removeTemporaryDirectory(directory) }

		let store = FeedSnapshotStore(directory: directory)
		await store.save(snapshot: FeedSnapshot(page: makePage()))

		await store.removeSnapshot()

		#expect(snapshotFileExists(in: directory) == false)
		#expect(await store.loadSnapshot() == nil)
	}

	@Test
	func removeSnapshotSucceedsWhenNothingIsStored() async {
		let directory = makeTemporaryDirectory()
		defer { removeTemporaryDirectory(directory) }

		await FeedSnapshotStore(directory: directory).removeSnapshot()

		#expect(snapshotFileExists(in: directory) == false)
	}

	@Test
	func scopesSnapshotsByAccount() async {
		let directory = makeTemporaryDirectory()
		defer { removeTemporaryDirectory(directory) }

		let snapshot = FeedSnapshot(
			page: makePage(),
			savedAt: recentWholeSecond()
		)
		let accountID = UUID()

		await FeedSnapshotStore(
			accountID: accountID,
			directory: directory
		).save(snapshot: snapshot)

		#expect(
			await FeedSnapshotStore(directory: directory).loadSnapshot() == nil
		)
		#expect(
			await FeedSnapshotStore(
				accountID: accountID,
				directory: directory
			).loadSnapshot() == snapshot
		)
	}
}

// MARK: - Helpers

private let snapshotFileName = "feed-snapshot.json"

private func makeTemporaryDirectory() -> URL {
	let directory = FileManager.default.temporaryDirectory
		.appending(path: UUID().uuidString)
	try? FileManager.default.createDirectory(
		at: directory,
		withIntermediateDirectories: true
	)
	return directory
}

private func removeTemporaryDirectory(_ directory: URL) {
	try? FileManager.default.removeItem(at: directory)
}

private func snapshotFileExists(in directory: URL) -> Bool {
	FileManager.default.fileExists(
		atPath: directory.appending(path: snapshotFileName).path(percentEncoded: false)
	)
}

private func write(_ contents: String, to directory: URL) {
	try? Data(contents.utf8).write(
		to: directory.appending(path: snapshotFileName)
	)
}

/// A current timestamp truncated to a whole second.
///
/// The store encodes dates as ISO8601, which drops sub-second precision, so
/// a `Date.now` fixture would not survive a round trip intact.
private func recentWholeSecond() -> Date {
	Date(timeIntervalSince1970: Date.now.timeIntervalSince1970.rounded(.down))
}

private func makePage() -> SocialFeedPage {
	SocialFeedPage(
		posts: [
			Post(
				id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
				author: Author(
					id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1)),
					username: "bird1",
					displayName: "Bird 1",
					avatarURL: nil
				),
				text: "Post 1",
				imageURL: nil,
				createdAt: Date(timeIntervalSince1970: 1),
				isLiked: false,
				likeCount: 1
			)
		],
		nextCursor: "next-page"
	)
}
