//
//  UniversityService.swift
//  Pathmate
//
//  Created by Omkar Lad on 10/10/2025.
//

import Foundation

/// Networking for OpenAlex "institutions" (AU education).
enum UniversityServiceError: Error { case badStatus(Int) }

struct UniversityService {
    /// Fetches all AU educational institutions once (single page).
    /// - Returns: A list of `Institution` values for client-side filtering.
    static func institutionsAU() async throws -> [Institution] {
        var comps = URLComponents(string: "https://api.openalex.org/institutions")!
        comps.queryItems = [
            .init(name: "filter", value: "country_code:AU,type:education"),
            .init(name: "per-page", value: "200"),
            .init(name: "sort", value: "display_name"),
            .init(name: "select", value: "id,display_name,geo")
        ]
        let url = comps.url!
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw UniversityServiceError.badStatus((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let decoded = try JSONDecoder().decode(OpenAlexEnvelope<Institution>.self, from: data)
        return decoded.results
    }
}
