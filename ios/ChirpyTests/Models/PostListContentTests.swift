//
//  PostListContentTests.swift
//  ChirpyTests
//
//  Created by Samuel Yanez on 10/8/26.
//

import Foundation
import Testing

@testable import Chirpy

@MainActor
struct PostListContentTests {
	@Test func firstPageDeduplicatesAndPreservesOrder() {
		let first = Post.preview
		let second = Post.flockPreview[1]
		let content = PostListContent(page: .init(posts: [first, second, first], nextCursor: "next"))
		#expect(content.posts == [first, second])
		#expect(content.nextCursor == "next")
		#expect(!content.isLoadingNextPage)
		#expect(content.paginationError == nil)
	}

	@Test func appendDeduplicatesAndResetsPaginationState() {
		let first = Post.preview
		let second = Post.flockPreview[1]
		var content = PostListContent(
			posts: [first],
			nextCursor: "next",
			isLoadingNextPage: true,
			paginationError: "Failed"
		)
		content.append(.init(posts: [first, second, second], nextCursor: "last"))
		#expect(content.posts == [first, second])
		#expect(content.nextCursor == "last")
		#expect(!content.isLoadingNextPage)
		#expect(content.paginationError == nil)
		content.append(.init(posts: [], nextCursor: nil))
		#expect(content.posts == [first, second])
		#expect(content.nextCursor == nil)
	}

	@Test func likeUpdatesChangeOnlyTheMatchingPost() {
		let posts = Post.flockPreview
		var content = PostListContent(posts: posts, nextCursor: "next")
		content.apply(.init(postID: posts[0].id, isLiked: false, likeCount: 42))
		var expected = posts
		expected[0].isLiked = false
		expected[0].likeCount = 42
		#expect(content.posts == expected)
		#expect(content.nextCursor == "next")

		let unchanged = content
		content.apply(.init(postID: UUID(), isLiked: true, likeCount: 1))
		#expect(content == unchanged)
	}

	@Test func removalPreservesPaginationAndMissingIDsAreHarmless() {
		var content = PostListContent(posts: [.preview], nextCursor: "next", isLoadingNextPage: true, paginationError: "Failed")
		content.remove(postID: UUID())
		#expect(content.posts == [.preview])
		content.remove(postID: Post.preview.id)
		#expect(content.posts.isEmpty)
		#expect(content.nextCursor == "next")
		#expect(content.isLoadingNextPage)
		#expect(content.paginationError == "Failed")
	}

	@Test func emptyPagesContinueLoadingUnlessPaginationFailed() {
		var content = PostListContent(posts: [.preview], nextCursor: "next")
		#expect(content.emptyPageCursor == nil)
		content.remove(postID: Post.preview.id)
		#expect(content.emptyPageCursor == "next")
		content.paginationError = "Failed"
		#expect(content.emptyPageCursor == nil)
	}

	@Test(arguments: [0, 1, 4, 5, 6, 10])
	func paginationThresholdUsesTheLastFivePosts(count: Int) {
		let posts = (0..<count)
			.map { _ in
				let sample = Post.preview
				return Post(
					id: UUID(),
					author: sample.author,
					text: sample.text,
					imageURL: sample.imageURL,
					createdAt: sample.createdAt,
					isLiked: sample.isLiked,
					likeCount: sample.likeCount
				)
			}
		let content = PostListContent(posts: posts, nextCursor: "next")
		for (index, post) in posts.enumerated() {
			#expect(content.isNearEnd(postID: post.id) == (index >= max(0, count - 5)))
		}
		#expect(!content.isNearEnd(postID: UUID()))
	}
}
