import Testing

@testable import Chirpy

@MainActor
struct FeedViewModelTests {
    @Test
    func testLoad() async {
        let page = SocialFeedPage(posts: [], nextCursor: "next-page")
        let viewModel = FeedViewModel(
            client: SocialFeedServiceStub(result: .success(page))
        )

        await viewModel.load()

        #expect(viewModel.state == .loaded(page: page))
    }

    @Test
    func testLoadError() async {
        let viewModel = FeedViewModel(
            client: SocialFeedServiceStub(result: .failure(.requestFailed))
        )

        await viewModel.load()

        #expect(viewModel.state == .error(message: "The feed couldn’t be loaded."))
    }
}

private nonisolated struct SocialFeedServiceStub: SocialFeedServicing {
    let result: Result<SocialFeedPage, TestError>

    func fetchPage(cursor: String?, limit: Int) async throws -> SocialFeedPage {
        try result.get()
    }
}

private nonisolated enum TestError: Error, Sendable {
    case requestFailed
}
