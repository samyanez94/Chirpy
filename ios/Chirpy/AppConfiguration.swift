//
//  AppConfiguration.swift
//  Chirpy
//
//  Created by Samuel Yanez on 9/1/26.
//

import Foundation

enum AppConfiguration {
	static let apiKey: String? = {
		guard let url = Bundle.main.url(forResource: "LocalConfiguration", withExtension: "plist"),
			let data = try? Data(contentsOf: url),
			let values = try? PropertyListDecoder().decode([String: String].self, from: data)
		else {
            return nil
        }
		return values["ChirpyAPIKey"]
	}()

	static let baseURL = URL(string: "https://ncmomgqxdwrjwmoihayz.supabase.co")!
}
