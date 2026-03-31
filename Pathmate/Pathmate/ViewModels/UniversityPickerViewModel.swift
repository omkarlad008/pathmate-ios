//
//  UniversityPickerViewModel.swift
//  Pathmate
//
//  Created by Omkar Lad on 10/10/2025.
//

import Foundation

/// View model for the dependent City → University pickers.
@MainActor
final class UniversityPickerViewModel: ObservableObject {
    @Published var institutions: [Institution] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    /// Unique, sorted city names derived from `institutions`.
    var cities: [String] {
        let set = Set(institutions.compactMap { $0.geo?.city?.trimmingCharacters(in: .whitespacesAndNewlines) }
                                   .filter { !$0.isEmpty })
        return set.sorted()
    }

    /// Institutions matching a given city (case-insensitive).
    func institutions(in city: String) -> [Institution] {
        institutions.filter { ($0.geo?.city ?? "").caseInsensitiveCompare(city) == .orderedSame }
    }

    /// Loads AU institutions once.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            institutions = try await UniversityService.institutionsAU()
            error = nil
        } catch {
            institutions = []
            self.error = "Couldn’t fetch universities. Please try again."
        }
    }
}
