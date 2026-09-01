//
//  SocialFeedClientTests.swift
//  ChirpyTests
//
//  Created by Samuel Yanez on 8/31/26.
//

import Foundation
import Testing
@testable import Chirpy

struct SocialFeedClientTests {
    @Test func testFetchPage() async throws {
        let fixtureURL = try #require(
            Bundle(for: NetworkingTestBundleToken.self).url(
                forResource: "social-feed-page",
                withExtension: "json"
            )
        )
        let data = try Data(contentsOf: fixtureURL)
        let baseURL = try #require(URL(string: "https://example.com"))
        let response = try #require(
            HTTPURLResponse(
                url: baseURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
        )
        let client = SocialFeedClient(
            baseURL: baseURL,
            httpClient: HTTPClientStub(data: data, response: response)
        )

        let page = try await client.fetchPage()

        #expect(page.posts.count == 1)
        #expect(page.nextCursor == "opaque-next-page-cursor")
    }

    @Test func testFetchPageBuildsRequest() async throws {
        let data = try fixtureData(named: "social-feed-page")
        let baseURL = try #require(URL(string: "https://example.com"))
        let response = try httpResponse(url: baseURL, statusCode: 200)
        let recorder = RequestRecorder()
        let client = SocialFeedClient(
            baseURL: baseURL,
            httpClient: HTTPClientStub(
                data: data,
                response: response,
                recorder: recorder
            )
        )

        _ = try await client.fetchPage(cursor: "opaque cursor/+", limit: 10)

        let recordedRequest = await recorder.onlyRequest()
        let request = try #require(recordedRequest)
        let url = try #require(request.url)
        let components = try #require(
            URLComponents(url: url, resolvingAgainstBaseURL: false)
        )

        #expect(request.httpMethod == "GET")
        #expect(components.path == "/functions/v1/social-feed/feed")
        #expect(components.queryItems?.first { $0.name == "limit" }?.value == "10")
        #expect(components.queryItems?.first { $0.name == "cursor" }?.value == "opaque cursor/+")
    }

    @Test func testFetchPageThrowsAPIError() async throws {
        let data = try fixtureData(named: "service-unavailable-error")
        let baseURL = try #require(URL(string: "https://example.com"))
        let response = try httpResponse(url: baseURL, statusCode: 503)
        let client = SocialFeedClient(
            baseURL: baseURL,
            httpClient: HTTPClientStub(data: data, response: response)
        )

        do {
            _ = try await client.fetchPage()
            Issue.record("Expected fetchPage() to throw an APIError.")
        } catch let error as APIError {
            #expect(error.code == "service_unavailable")
            #expect(error.message == "A development failure was requested.")
            #expect(error.requestID.uuidString == "00000000-0000-4000-8000-000000000001")
        } catch {
            Issue.record("Expected APIError, but received \(error).")
        }
    }

    @Test func testFetchPageRejectsNonHTTPResponse() async throws {
        let baseURL = try #require(URL(string: "https://example.com"))
        let response = URLResponse(
            url: baseURL,
            mimeType: "application/json",
            expectedContentLength: 0,
            textEncodingName: nil
        )
        let client = SocialFeedClient(
            baseURL: baseURL,
            httpClient: HTTPClientStub(data: Data(), response: response)
        )

        do {
            _ = try await client.fetchPage()
            Issue.record("Expected fetchPage() to reject a non-HTTP response.")
        } catch let error as URLError {
            #expect(error.code == .badServerResponse)
        } catch {
            Issue.record("Expected URLError.badServerResponse, but received \(error).")
        }
    }

    private func fixtureData(named name: String) throws -> Data {
        let fixtureURL = try #require(
            Bundle(for: NetworkingTestBundleToken.self).url(
                forResource: name,
                withExtension: "json"
            )
        )
        return try Data(contentsOf: fixtureURL)
    }

    private func httpResponse(url: URL, statusCode: Int) throws -> HTTPURLResponse {
        try #require(
            HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )
        )
    }
}

private nonisolated struct HTTPClientStub: HTTPClient {
    let data: Data
    let response: URLResponse
    let recorder: RequestRecorder?

    init(data: Data, response: URLResponse, recorder: RequestRecorder? = nil) {
        self.data = data
        self.response = response
        self.recorder = recorder
    }

    func send(request: URLRequest) async throws -> (Data, URLResponse) {
        await recorder?.record(request)
        return (data, response)
    }
}

private actor RequestRecorder {
    private var requests: [URLRequest] = []

    func record(_ request: URLRequest) {
        requests.append(request)
    }

    func onlyRequest() -> URLRequest? {
        guard requests.count == 1 else {
            return nil
        }
        return requests[0]
    }
}

private final class NetworkingTestBundleToken {}
