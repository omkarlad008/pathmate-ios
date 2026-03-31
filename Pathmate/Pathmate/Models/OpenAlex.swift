//
//  OpenAlex.swift
//  Pathmate
//
//  Created by Omkar Lad on 10/10/2025.
//

import Foundation

/// OpenAlex top-level envelope for list responses.
struct OpenAlexEnvelope<T: Decodable>: Decodable {
    let results: [T]
}

/// Minimal institution model for the pickers.
/// We keep `id` for stable identity; we don't persist it.
struct Institution: Identifiable, Decodable, Hashable {
    let id: String
    let display_name: String
    let geo: Geo?

    struct Geo: Decodable, Hashable {
        let city: String?
        let region: String?
        let country_code: String?
        let country: String?
        let latitude: Double?
        let longitude: Double?
    }
}
