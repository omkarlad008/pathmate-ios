//
//  UserProfileEntity.swift
//  Pathmate
//
//  Created by Omkar Lad on 14/10/2025.
//

// MARK: - Imports
// SwiftData for local persistence; Foundation for basic types.
import Foundation
import SwiftData

/// **UserProfileEntity (SwiftData)**
///
/// Local, on-device snapshot of the user's basic setup information.
/// Kept this minimal and focused on what the app actually uses for personalization.
@Model
final class UserProfileEntity {
    // MARK: - Identity & Timestamps
    /// Single-user app: we’ll generally keep just one profile row.
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Core fields (mirrors your Setup form)
    var fullName: String
    var email: String
    var studyLevel: String           // "Bachelor" / "Master"
    var intakeMonth: Int             // 1...12
    var intakeYear: Int              // e.g., 2025
    var fromCountry: String          // e.g., "India"
    var toCountry: String            // e.g., "Australia"
    var cityName: String             // e.g., "Melbourne"
    var universityName: String       // e.g., "RMIT University"
    var acceptedPolicy: Bool

    // MARK: - Init
    init(
        fullName: String,
        email: String,
        studyLevel: String,
        intakeMonth: Int,
        intakeYear: Int,
        fromCountry: String,
        toCountry: String,
        cityName: String,
        universityName: String,
        acceptedPolicy: Bool,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.fullName = fullName
        self.email = email
        self.studyLevel = studyLevel
        self.intakeMonth = intakeMonth
        self.intakeYear = intakeYear
        self.fromCountry = fromCountry
        self.toCountry = toCountry
        self.cityName = cityName
        self.universityName = universityName
        self.acceptedPolicy = acceptedPolicy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
