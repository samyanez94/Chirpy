//
//  LocalPostDeletionTests.swift
//  ChirpyTests
//
//  Created by Samuel Yanez on 10/9/26.
//

import Foundation
import Testing

@testable import Chirpy

@MainActor
struct LocalPostDeletionTests {
	@Test func localRemovalSurvivesRefreshAndPaginationInEveryScreen() async {
		let posts = [Post.preview]
		let client = PreviewChirpyClient(result: .success(.init(posts: posts, nextCursor: "next")))
		let feed = FeedViewModel(client: client)
		await feed.load()
		feed.removePost(postID: posts[0].id)
		await feed.loadNextPage()
		await feed.refresh()
		#expect(feed.state == .loaded(content: .init(posts: [], nextCursor: "next")))

		let search = SearchViewModel(query: "Post", client: client)
		await search.load()
		search.removePost(postID: posts[0].id)
		await search.loadNextPage()
		await search.refresh()
		#expect(search.state == .loaded(content: .init(posts: [], nextCursor: "next")))

		let profile = ProfileViewModel(client: client, profileID: posts[0].author.id)
		await profile.load()
		profile.removePost(postID: posts[0].id)
		await profile.loadNextPage()
		await profile.refresh()
		#expect(profile.postsState == .loaded(.init(posts: [], nextCursor: "next")))
	}

	@Test func deletingInOneScreenDoesNotAlterAnotherScreen() async {
		let client = PreviewChirpyClient(result: .success(.init(posts: [.preview], nextCursor: nil)))
		let feed = FeedViewModel(client: client)
		let search = SearchViewModel(query: "Post", client: client)
		await feed.load()
		await search.load()
		feed.removePost(postID: Post.preview.id)
		#expect(feed.state == .loaded(content: .init(posts: [], nextCursor: nil)))
		#expect(search.state == .loaded(content: .init(posts: [.preview], nextCursor: nil)))
	}
}
