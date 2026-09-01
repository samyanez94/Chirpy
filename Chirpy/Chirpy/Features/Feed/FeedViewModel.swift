//
//  FeedViewModel.swift
//  Chirpy
//
//  Created by Samuel Yanez on 9/1/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class FeedViewModel {
    
    enum State: Equatable {
        case idle
        case loading
        case loaded(page: SocialFeedPage)
        case error(message: String)
    }
    
    private let client: any SocialFeedServicing
    
    private(set) var state: State = .idle
    
    init(client: any SocialFeedServicing) {
        self.client = client
    }
    
    func load() async {
        state = .loading
        do {
            let page = try await client.fetchPage(cursor: nil, limit: 20)
            state = .loaded(page: page)
        } catch {
            state = .error(message: "The feed couldn’t be loaded.")
        }
    }
}
