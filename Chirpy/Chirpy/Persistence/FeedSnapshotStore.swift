//
//  FeedSnapshotStore.swift
//  Chirpy
//
//  Created by Codex on 9/1/26.
//

import Foundation
import OSLog

/// A file-backed store for the first social-feed page.
actor FeedSnapshotStore: FeedSnapshotStoring {

	/// The longest a snapshot may be used before it is treated as expired.
	///
	/// Past this age the posts are old enough that their like counts are more
	/// misleading than the empty state they replace.
	static let defaultMaximumAge: TimeInterval = 24 * 60 * 60

	private static let logger = Logger(
		subsystem: "Chirpy",
		category: "FeedSnapshotStore"
	)

	private let fileURL: URL

	private let maximumAge: TimeInterval

	/// Creates a snapshot store scoped to an account when one is available.
	///
	/// Passing an account identifier prevents personalized feed state from being
	/// shared between accounts. Until Chirpy has authentication, the default file
	/// is used.
	init(
		accountID: UUID? = nil,
		directory: URL = .cachesDirectory,
		maximumAge: TimeInterval = FeedSnapshotStore.defaultMaximumAge
	) {
		let suffix = accountID.map { "-\($0.uuidString.lowercased())" } ?? ""
		fileURL = directory.appending(
			path: "feed-snapshot\(suffix).json"
		)
		self.maximumAge = maximumAge
	}

	/// Returns the stored snapshot, or `nil` when there is no usable one.
	///
	/// A snapshot that is expired, written by another version, or corrupt is
	/// deleted rather than left to fail again on the next launch.
	func loadSnapshot() async -> FeedSnapshot? {
		guard let data = readSnapshotData() else {
			return nil
		}

		let decoder = Self.makeDecoder()

		// Decoding the version on its own keeps the check meaningful: a payload
		// whose shape changed would otherwise fail to decode before ever
		// reaching a version comparison.
		guard
			let envelope = try? decoder.decode(
				SnapshotEnvelope.self,
				from: data
			),
			envelope.version == FeedSnapshot.currentVersion
		else {
			discardSnapshot(because: "it is unreadable or has another version")
			return nil
		}

		guard let snapshot = try? decoder.decode(FeedSnapshot.self, from: data)
		else {
			discardSnapshot(because: "its contents could not be decoded")
			return nil
		}

		// A negative age means the device clock moved backwards since the
		// snapshot was written, which would otherwise keep it alive forever.
		let age = Date.now.timeIntervalSince(snapshot.savedAt)

		guard (0...maximumAge).contains(age) else {
			discardSnapshot(because: "it is outside the maximum age")
			return nil
		}

		return snapshot
	}

	func save(snapshot: FeedSnapshot) async {
		do {
			let data = try Self.makeEncoder().encode(snapshot)
			try FileManager.default.createDirectory(
				at: fileURL.deletingLastPathComponent(),
				withIntermediateDirectories: true
			)
			try data.write(to: fileURL, options: .atomic)
		} catch {
			Self.logger.error(
				"Could not save the feed snapshot: \((error as NSError).code, privacy: .public)"
			)
		}
	}

	func removeSnapshot() async {
		deleteSnapshotFile()
	}

	/// Reads the snapshot file, distinguishing "not written yet" from failure.
	///
	/// A read failure is deliberately not treated as corruption. It can be
	/// transient — most notably when data protection makes the file unreadable
	/// while the device is locked — and deleting on that would throw away a
	/// perfectly good snapshot.
	private func readSnapshotData() -> Data? {
		do {
			return try Data(contentsOf: fileURL)
		} catch let error as CocoaError where error.code == .fileReadNoSuchFile {
			return nil
		} catch {
			Self.logger.error(
				"Could not read the feed snapshot: \((error as NSError).code, privacy: .public)"
			)
			return nil
		}
	}

	private func discardSnapshot(because reason: StaticString) {
		Self.logger.notice(
			"Discarding the feed snapshot because \(reason, privacy: .public)"
		)
		deleteSnapshotFile()
	}

	private func deleteSnapshotFile() {
		do {
			try FileManager.default.removeItem(at: fileURL)
		} catch let error as CocoaError where error.code == .fileNoSuchFile {
			return
		} catch {
			Self.logger.error(
				"Could not remove the feed snapshot: \((error as NSError).code, privacy: .public)"
			)
		}
	}

	private static func makeDecoder() -> JSONDecoder {
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		return decoder
	}

	private static func makeEncoder() -> JSONEncoder {
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		return encoder
	}
}

// MARK: - SnapshotEnvelope

/// The version field of a stored snapshot, decoded on its own so an
/// incompatible payload is rejected by version rather than by decode failure.
private nonisolated struct SnapshotEnvelope: Decodable, Sendable {
	let version: Int
}
