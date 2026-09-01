//
//  ChirpyApp.swift
//  Chirpy
//
//  Created by Samuel Yanez on 8/31/26.
//

import SwiftUI

@main
struct ChirpyApp: App {
    var body: some Scene {
        WindowGroup {
            FeedView(
                viewModel: FeedViewModel(
                    client: SocialFeedClient(
                        baseURL: AppConfiguration.baseURL
                    )
                )
            )
        }
    }
}
