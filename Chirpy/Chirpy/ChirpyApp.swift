//
//  ChirpyApp.swift
//  Chirpy
//
//  Created by Samuel Yanez on 8/31/26.
//

import SwiftUI

@main
struct ChirpyApp: App {

	private let client = ChirpyClient(
		baseURL: AppConfiguration.baseURL,
		httpClient: AuthenticatedHTTPClient(apiKey: AppConfiguration.apiKey)
	)

	var body: some Scene {
		WindowGroup {
			ChirpyRootView(client: client)
		}
	}
}
